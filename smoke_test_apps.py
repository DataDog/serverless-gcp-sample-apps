#!/usr/bin/env python3

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.
#
# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2026-present Datadog, Inc.

"""Smoke-test all deployed GCP sample apps.

Discovers sample apps the same way ``deploy-all-apps.sh`` does, invokes each
one (HTTP for Cloud Run services and Cloud Run Functions; ``gcloud run jobs
execute`` for Cloud Run Jobs), then queries Datadog to confirm spans, logs,
and (for the two apps that emit it) the ``our-sample-app.sample-metric``
custom metric.

Stdlib-only. Requires ``gcloud`` on PATH and the environment variables
``DD_API_KEY`` and ``DD_APP_KEY``.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Iterable


# ---------------------------------------------------------------------------
# Constants -- kept in sync with deploy-all-apps.sh
# ---------------------------------------------------------------------------

PRODUCTS = [
    "cloud-run/in-container/",
    "cloud-run/sidecar/",
    "cloud-run-functions/",
    "cloud-run-jobs/",
]
LANGUAGES = ["python", "node", "go", "java", "dotnet", "ruby", "php"]

# Apps that emit the custom metric (Datadog normalizes dashes to underscores
# on ingest, so the queryable name is ``our_sample_app.sample_metric``). All
# other apps mark the metric column as "—" rather than failing.
METRIC_REQUIRED_SERVICES = {
    "gcp-sample-apps-cloud-run-functions-python",
    "gcp-sample-apps-cloud-run-sidecar-python",
}
CUSTOM_METRIC_NAME = "our_sample_app.sample_metric"

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))

# ANSI markers used in the per-app result rows.
OK = "✅"
FAIL = "❌"
SKIP = "—"


# ---------------------------------------------------------------------------
# App model
# ---------------------------------------------------------------------------


class App:
    """One sample-app target."""

    def __init__(self, product: str, language: str) -> None:
        self.product = product  # e.g. "cloud-run/sidecar/"
        self.language = language
        # Mirror deploy-all-apps.sh:36 exactly.
        bare = product.rstrip("/").replace("/", "-")
        self.service = f"gcp-sample-apps-{bare}-{language}"

        # Result fields, populated as the run progresses.
        self.invoked_ok: bool | None = None
        self.invoke_detail: str = ""
        self.spans_ok: bool | None = None
        self.logs_ok: bool | None = None
        self.metric_ok: bool | None = None  # None => not applicable

    @property
    def kind(self) -> str:
        """One of "service" (Cloud Run service or Cloud Run Function) or
        "job" (Cloud Run Job)."""
        if self.product.startswith("cloud-run-jobs"):
            return "job"
        return "service"

    @property
    def metric_required(self) -> bool:
        return self.service in METRIC_REQUIRED_SERVICES

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"App({self.service})"


# ---------------------------------------------------------------------------
# Discovery & filtering
# ---------------------------------------------------------------------------


def discover_apps(repo_root: str) -> list[App]:
    """Walk the PRODUCTS x LANGUAGES matrix, skipping missing directories."""
    apps: list[App] = []
    for product in PRODUCTS:
        for language in LANGUAGES:
            path = os.path.join(repo_root, product, language)
            if not os.path.isdir(path):
                continue
            apps.append(App(product, language))
    return apps


def _split_csv(values: Iterable[str]) -> list[str]:
    """Flatten repeated/comma-separated CLI values into a list."""
    out: list[str] = []
    for v in values:
        for piece in v.split(","):
            piece = piece.strip()
            if piece:
                out.append(piece)
    return out


def filter_apps(
    apps: list[App],
    app_patterns: list[str],
    products: list[str],
    languages: list[str],
) -> list[App]:
    """Apply --app / --product / --language filters.

    Multiple flag types AND together; values within a single flag OR together.
    """
    def app_matches(app: App) -> bool:
        if app_patterns:
            if not any(
                fnmatch.fnmatchcase(app.service, pat) or app.service == pat
                for pat in app_patterns
            ):
                return False
        if products:
            # Match against the bare product name, e.g. "cloud-run/sidecar".
            bare = app.product.rstrip("/")
            if not any(p == bare or p == app.product for p in products):
                return False
        if languages and app.language not in languages:
            return False
        return True

    return [a for a in apps if app_matches(a)]


# ---------------------------------------------------------------------------
# gcloud helpers
# ---------------------------------------------------------------------------


def _run(cmd: list[str], timeout: int = 120) -> tuple[int, str, str]:
    """Run a subprocess, returning (rc, stdout, stderr). Never raises."""
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError as e:
        return 127, "", str(e)
    except subprocess.TimeoutExpired as e:
        return 124, e.stdout or "", f"timeout after {timeout}s"
    return proc.returncode, proc.stdout, proc.stderr


def gcloud_service_url(service: str, region: str, project: str) -> str | None:
    rc, out, _ = _run(
        [
            "gcloud", "run", "services", "describe", service,
            "--region", region,
            "--project", project,
            "--format", "value(status.url)",
        ],
        timeout=60,
    )
    if rc != 0:
        return None
    url = out.strip()
    return url or None


def gcloud_identity_token() -> str | None:
    rc, out, _ = _run(["gcloud", "auth", "print-identity-token"], timeout=30)
    if rc != 0:
        return None
    token = out.strip()
    return token or None


def gcloud_execute_job(service: str, region: str, project: str) -> tuple[bool, str]:
    rc, _, err = _run(
        [
            "gcloud", "run", "jobs", "execute", service,
            "--region", region,
            "--project", project,
            "--wait",
        ],
        timeout=600,
    )
    if rc == 0:
        return True, "executed"
    return False, (err or "").strip().splitlines()[-1] if err else f"rc={rc}"


# ---------------------------------------------------------------------------
# Phase 1: invoke
# ---------------------------------------------------------------------------


def invoke_service(app: App, region: str, project: str, invocations: int, token: str) -> None:
    url = gcloud_service_url(app.service, region, project)
    if not url:
        app.invoked_ok = False
        app.invoke_detail = "no url"
        return
    last_status = None
    last_err = None
    successes = 0
    for _ in range(invocations):
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                last_status = resp.status
                if 200 <= resp.status < 400:
                    successes += 1
        except urllib.error.HTTPError as e:
            last_status = e.code
            last_err = f"HTTP {e.code}"
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            last_err = str(e)
    app.invoked_ok = successes == invocations
    if app.invoked_ok:
        app.invoke_detail = f"{successes}/{invocations} HTTP {last_status}"
    else:
        app.invoke_detail = last_err or f"{successes}/{invocations} HTTP {last_status}"


def invoke_job(app: App, region: str, project: str) -> None:
    ok, detail = gcloud_execute_job(app.service, region, project)
    app.invoked_ok = ok
    app.invoke_detail = detail


def invoke_all(
    apps: list[App],
    region: str,
    project: str,
    invocations: int,
    max_workers: int = 8,
) -> None:
    token = gcloud_identity_token()
    if token is None:
        print("ERROR: gcloud auth print-identity-token failed", file=sys.stderr)
        # Continue anyway -- service invocations will fail and be reported.

    def run_one(app: App) -> None:
        if app.kind == "job":
            invoke_job(app, region, project)
        else:
            invoke_service(app, region, project, invocations, token or "")

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as ex:
        list(ex.map(run_one, apps))


# ---------------------------------------------------------------------------
# Phase 2: Datadog queries
# ---------------------------------------------------------------------------


DEBUG = False


def _debug(label: str, value) -> None:
    if not DEBUG:
        return
    try:
        text = value if isinstance(value, str) else json.dumps(value, default=str)
    except Exception:
        text = repr(value)
    print(f"[debug] {label}: {text}", file=sys.stderr)


def _dd_post(url: str, body: dict, headers: dict, timeout: int = 60) -> dict:
    data = json.dumps(body).encode("utf-8")
    _debug(f"POST {url}", body)
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
            _debug(f"POST {url} response", payload)
            return payload
    except urllib.error.HTTPError as e:
        body_text = ""
        try:
            body_text = e.read().decode("utf-8", errors="replace")[:1000]
        except Exception:
            pass
        raise RuntimeError(f"{e.code} {e.reason}: {body_text}") from e


def _dd_get(url: str, headers: dict, timeout: int = 60) -> dict:
    _debug(f"GET {url}", "")
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
            _debug(f"GET {url} response", payload)
            return payload
    except urllib.error.HTTPError as e:
        body_text = ""
        try:
            body_text = e.read().decode("utf-8", errors="replace")[:1000]
        except Exception:
            pass
        raise RuntimeError(f"{e.code} {e.reason}: {body_text}") from e


def _service_filter_query(services: list[str]) -> str:
    if not services:
        return "service:*"
    joined = " OR ".join(services)
    return f"service:({joined})"


def _spans_aggregate_payload(services: list[str], from_iso: str) -> dict:
    # v2 spans/analytics/aggregate wraps the request in data.type.attributes.
    return {
        "data": {
            "type": "aggregate_request",
            "attributes": {
                "compute": [{"aggregation": "count", "type": "total"}],
                "group_by": [{"facet": "service", "limit": 100}],
                "filter": {
                    "query": _service_filter_query(services),
                    "from": from_iso,
                    "to": "now",
                },
            },
        }
    }


def _logs_aggregate_payload(services: list[str], from_iso: str) -> dict:
    # v2 logs/analytics/aggregate uses a flat top-level payload (no data wrapper).
    return {
        "compute": [{"aggregation": "count", "type": "total"}],
        "group_by": [{"facet": "service", "limit": 100}],
        "filter": {
            "query": _service_filter_query(services),
            "from": from_iso,
            "to": "now",
        },
    }


def _compute_total(computes: dict) -> int:
    """A `computes` map value is either a scalar (total) or a list of {time, value} (timeseries)."""
    if not isinstance(computes, dict) or not computes:
        return 0
    # Take the first compute key (we only ever request one).
    v = next(iter(computes.values()))
    if isinstance(v, (int, float)):
        return int(v)
    if isinstance(v, str):
        try:
            return int(float(v))
        except ValueError:
            return 0
    if isinstance(v, list):
        total = 0.0
        for point in v:
            if isinstance(point, dict) and point.get("value") is not None:
                try:
                    total += float(point["value"])
                except (TypeError, ValueError):
                    pass
        return int(total)
    return 0


def _parse_aggregate_buckets(payload: dict) -> dict[str, int]:
    """Extract a {service: count} map from a v2 analytics/aggregate response.

    Spans response shape (confirmed via docs):
      {"data": [{"type": "bucket", "attributes": {"by": {"service": "..."}, "computes": {...}}}]}
    Logs response shape is undocumented in the public OpenAPI page; we accept either:
      {"data": {"buckets": [{"by": ..., "computes": ...}]}}
      {"data": [{"attributes": {"by": ..., "computes": ...}}]}
    `computes` values are either scalars (type=total) or lists of {time, value} (type=timeseries).
    """
    counts: dict[str, int] = {}
    data = payload.get("data")
    bucket_attrs: list[dict] = []

    if isinstance(data, dict):
        if isinstance(data.get("buckets"), list):
            bucket_attrs.extend(b for b in data["buckets"] if isinstance(b, dict))
        attrs = data.get("attributes")
        if isinstance(attrs, dict) and isinstance(attrs.get("buckets"), list):
            bucket_attrs.extend(b for b in attrs["buckets"] if isinstance(b, dict))
    elif isinstance(data, list):
        for item in data:
            if not isinstance(item, dict):
                continue
            # Two possible shapes per item: flat {by, computes} or {attributes: {by, computes}}.
            if "attributes" in item and isinstance(item["attributes"], dict):
                bucket_attrs.append(item["attributes"])
            else:
                bucket_attrs.append(item)

    for b in bucket_attrs:
        by = b.get("by") or {}
        svc = by.get("service") or by.get("@service")
        if not svc:
            continue
        # Spans use `compute` (singular, scalar); timeseries use `computes` (plural, list).
        computes = b.get("compute") or b.get("computes") or {}
        counts[svc] = _compute_total(computes)
    return counts


def query_spans(dd_site: str, services: list[str], from_iso: str, headers: dict) -> dict[str, int]:
    url = f"https://api.{dd_site}/api/v2/spans/analytics/aggregate"
    payload = _dd_post(url, _spans_aggregate_payload(services, from_iso), headers)
    return _parse_aggregate_buckets(payload)


def query_logs(dd_site: str, services: list[str], from_iso: str, headers: dict) -> dict[str, int]:
    url = f"https://api.{dd_site}/api/v2/logs/analytics/aggregate"
    payload = _dd_post(url, _logs_aggregate_payload(services, from_iso), headers)
    return _parse_aggregate_buckets(payload)


def query_metric(dd_site: str, from_epoch: int, to_epoch: int, headers: dict) -> dict[str, float]:
    """Return {service: total_points} for the custom sample metric."""
    q = f"sum:{CUSTOM_METRIC_NAME}{{*}} by {{service}}.as_count()"
    params = urllib.parse.urlencode({"from": from_epoch, "to": to_epoch, "query": q})
    url = f"https://api.{dd_site}/api/v1/query?{params}"
    payload = _dd_get(url, headers)
    out: dict[str, float] = {}
    for series in payload.get("series", []) or []:
        scope = series.get("scope", "") or ""
        # Scope looks like "service:foo".
        svc = None
        for piece in scope.split(","):
            piece = piece.strip()
            if piece.startswith("service:"):
                svc = piece.split(":", 1)[1]
                break
        if not svc:
            tag_set = series.get("tag_set", []) or []
            for t in tag_set:
                if isinstance(t, str) and t.startswith("service:"):
                    svc = t.split(":", 1)[1]
                    break
        if not svc:
            continue
        total = 0.0
        for point in series.get("pointlist", []) or []:
            if isinstance(point, list) and len(point) >= 2 and point[1] is not None:
                try:
                    total += float(point[1])
                except (TypeError, ValueError):
                    pass
        out[svc] = total
    return out


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def _mark(ok: bool | None, label: str) -> str:
    if ok is None:
        return f"{SKIP} {label}"
    return f"{(OK if ok else FAIL)} {label}"


def format_row(app: App) -> str:
    cells = [
        _mark(app.invoked_ok, "invoke"),
        _mark(app.spans_ok, "spans"),
        _mark(app.logs_ok, "logs"),
        _mark(app.metric_ok, "metric"),
    ]
    return f"{app.service:<55} " + " ".join(cells)


def app_failed(app: App) -> bool:
    if app.invoked_ok is False:
        return True
    if app.spans_ok is False:
        return True
    if app.logs_ok is False:
        return True
    # metric_ok is only required when it is not None
    if app.metric_ok is False:
        return True
    return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Smoke-test deployed GCP sample apps via Datadog.",
    )
    p.add_argument(
        "--app", action="append", default=[],
        help="Filter by service name (exact, comma-separated, or glob). Repeatable.",
    )
    p.add_argument(
        "--product", action="append", default=[],
        help="Filter by product (comma-separated). Repeatable.",
    )
    p.add_argument(
        "--language", action="append", default=[],
        help="Filter by language (comma-separated). Repeatable.",
    )
    p.add_argument(
        "--delay", type=int, default=_env_int("SMOKE_DELAY", 90),
        help="Seconds to wait between invocation and first Datadog check (env SMOKE_DELAY, default 90).",
    )
    p.add_argument(
        "--invocations", type=int, default=_env_int("SMOKE_INVOCATIONS", 3),
        help="HTTP invocations per service (env SMOKE_INVOCATIONS, default 3).",
    )
    p.add_argument(
        "--project", default=os.environ.get("PROJECT_ID", "datadog-serverless-gcp-demo"),
        help="GCP project (env PROJECT_ID).",
    )
    p.add_argument(
        "--region", default=os.environ.get("REGION", "us-central1"),
        help="GCP region (env REGION).",
    )
    p.add_argument(
        "--dd-site", default=os.environ.get("DD_SITE", "datadoghq.com"),
        help="Datadog site (env DD_SITE).",
    )
    p.add_argument(
        "--debug", action="store_true",
        help="Dump Datadog request/response bodies to stderr.",
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])

    global DEBUG
    DEBUG = bool(args.debug)

    # Fail-fast: required Datadog credentials.
    dd_api_key = os.environ.get("DD_API_KEY")
    dd_app_key = os.environ.get("DD_APP_KEY")
    missing = [n for n, v in (("DD_API_KEY", dd_api_key), ("DD_APP_KEY", dd_app_key)) if not v]
    if missing:
        print(f"ERROR: missing required env vars: {', '.join(missing)}", file=sys.stderr)
        return 2

    if shutil.which("gcloud") is None:
        print("ERROR: gcloud not found on PATH", file=sys.stderr)
        return 2

    dd_headers = {
        "DD-API-KEY": dd_api_key,
        "DD-APPLICATION-KEY": dd_app_key,
        "Content-Type": "application/json",
    }

    all_apps = discover_apps(REPO_ROOT)
    app_patterns = _split_csv(args.app)
    product_filters = _split_csv(args.product)
    language_filters = _split_csv(args.language)
    apps = filter_apps(all_apps, app_patterns, product_filters, language_filters)

    if not apps:
        print("ERROR: no apps matched filters. Discovered:", file=sys.stderr)
        for a in all_apps:
            print(f"  {a.service}", file=sys.stderr)
        return 2

    print(f"Smoke-testing {len(apps)} app(s):")
    for a in apps:
        print(f"  - {a.service}")
    print()

    # Phase 1: invoke. Record start time *before* the first invocation so the
    # Datadog query window captures everything.
    invoke_start_utc = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    invoke_start_epoch = int(time.time())
    print(f"Phase 1: invoking apps (start={invoke_start_utc})")
    invoke_all(apps, args.region, args.project, args.invocations)

    # Phase 2: wait, then query Datadog (3 batched calls).
    print(f"Sleeping {args.delay}s before Datadog checks...")
    time.sleep(args.delay)

    service_names = [a.service for a in apps]

    def _safe_aggregate(fn, label: str) -> dict[str, int]:
        try:
            return fn(args.dd_site, service_names, invoke_start_utc, dd_headers)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"WARN: Datadog {label} query failed: {e}", file=sys.stderr)
            return {}

    span_counts = _safe_aggregate(query_spans, "spans")
    log_counts = _safe_aggregate(query_logs, "logs")

    # Pad the `from` for metric queries because Datadog returns 1-minute buckets
    # keyed on the bucket-start time. A metric emitted at 20:28:05 lands in the
    # 20:28:00 bucket, which would otherwise be filtered out if from=20:28:05.
    metric_from = invoke_start_epoch - 120
    try:
        metric_totals = query_metric(args.dd_site, metric_from, int(time.time()), dd_headers)
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
        print(f"WARN: Datadog metric query failed: {e}", file=sys.stderr)
        metric_totals = {}

    for a in apps:
        a.spans_ok = span_counts.get(a.service, 0) > 0
        a.logs_ok = log_counts.get(a.service, 0) > 0
        if a.metric_required:
            a.metric_ok = metric_totals.get(a.service, 0) > 0
        else:
            a.metric_ok = None  # marked as "—" in the row

    # Retry once for any signal that didn't show up the first time.
    # Includes the custom metric since dogstatsd flush latency can exceed the
    # initial delay (sidecar buffers, function cold-start, etc.).
    def _needs_retry(a: App) -> bool:
        return (
            a.spans_ok is False
            or a.logs_ok is False
            or (a.metric_required and a.metric_ok is False)
        )

    missing_services = [a.service for a in apps if _needs_retry(a)]
    if missing_services:
        # Retry waits the full --delay again so the total ingestion window is ~2x.
        # Spans/logs indexing pipelines commonly need 60-120s after emission.
        retry_delay = max(1, args.delay)
        print(
            f"Retrying spans+logs+metric for {len(missing_services)} service(s) after {retry_delay}s..."
        )
        time.sleep(retry_delay)
        try:
            span_counts2 = query_spans(args.dd_site, missing_services, invoke_start_utc, dd_headers)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"WARN: Datadog spans retry failed: {e}", file=sys.stderr)
            span_counts2 = {}
        try:
            log_counts2 = query_logs(args.dd_site, missing_services, invoke_start_utc, dd_headers)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"WARN: Datadog logs retry failed: {e}", file=sys.stderr)
            log_counts2 = {}
        try:
            metric_totals2 = query_metric(args.dd_site, metric_from, int(time.time()), dd_headers)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"WARN: Datadog metric retry failed: {e}", file=sys.stderr)
            metric_totals2 = {}
        retry_set = set(missing_services)
        for a in apps:
            if a.service not in retry_set:
                continue
            if a.spans_ok is False and span_counts2.get(a.service, 0) > 0:
                a.spans_ok = True
            if a.logs_ok is False and log_counts2.get(a.service, 0) > 0:
                a.logs_ok = True
            if a.metric_required and a.metric_ok is False and metric_totals2.get(a.service, 0) > 0:
                a.metric_ok = True

    # Report.
    print()
    print("Results:")
    for a in apps:
        print(format_row(a))

    failed = [a for a in apps if app_failed(a)]
    print()
    print(f"{len(apps)} apps · {len(apps) - len(failed)} ok · {len(failed)} failed")

    # Helpful diagnostic for any invoke failures.
    for a in apps:
        if a.invoked_ok is False and a.invoke_detail:
            print(f"  invoke {a.service}: {a.invoke_detail}", file=sys.stderr)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
