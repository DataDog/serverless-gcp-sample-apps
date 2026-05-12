#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2026-present Datadog, Inc.

# ----------------------------------------------------------------------------
# ONE-OFF SCRIPT
#
# Companion: restore-current.sh
#
# Tied to the smoke-test investigation kicked off by commit 5c5c41f (the
# initial smoke_test_apps.py addition). For each deployed sample app, this
# script captures the exact currently-serving revision (services / functions)
# or image digest (jobs) and flips it to the immediately prior revision /
# digest, so we can re-run smoke_test_apps.py against the previous version
# and tell pre-existing failures apart from regressions introduced by recent
# deploys.
#
# Writes .rollback-state.tsv at the repo root. restore-current.sh consumes
# that file to flip everything back to the captured pointer (NOT --to-latest,
# because someone could redeploy mid-investigation and we'd silently restore
# to the wrong revision).
#
# Safe to delete once the investigation is done, but harmless to keep — we
# may want this dance again.
# ----------------------------------------------------------------------------

set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ID="datadog-serverless-gcp-demo"
REGION="us-central1"
REPO_NAME="gcp-sample-apps"

PRODUCTS=("cloud-run/in-container/" "cloud-run/sidecar/" "cloud-run-functions/" "cloud-run-jobs/")
LANGUAGES=("python" "node" "go" "java" "dotnet" "ruby" "php")

STATE_FILE=".rollback-state.tsv"

# Color codes
GREEN="\033[0;32m"
YELLOW_BOLD="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Summary rows accumulated and printed at the end.
# Format: "status<TAB>kind<TAB>name<TAB>detail"
SUMMARY_ROWS=()

if [[ -f "$STATE_FILE" ]]; then
  echo -e "${RED}error: $STATE_FILE already exists — run restore-current.sh first or remove it manually if you're sure.${RESET}" >&2
  exit 1
fi

# Truncate / create the state file.
: > "$STATE_FILE"

is_job_product() {
  local product="$1"
  [[ "$product" == "cloud-run-jobs/" ]]
}

rollback_service() {
  local name="$1"
  local kind="$2" # "service" or "function"

  # Revisions sorted newest-first.
  local revisions
  if ! revisions=$(gcloud run revisions list \
      --service="$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --sort-by="~metadata.creationTimestamp" \
      --format="value(metadata.name)" 2>/dev/null); then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: could not list revisions (service may not exist)${RESET}"
    SUMMARY_ROWS+=("SKIP	$kind	$name	service not found")
    return 0
  fi

  local rev_count
  rev_count=$(echo "$revisions" | grep -c . || true)
  if [[ "$rev_count" -lt 2 ]]; then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: only $rev_count revision(s)${RESET}"
    SUMMARY_ROWS+=("SKIP	$kind	$name	only $rev_count revision(s)")
    return 0
  fi

  local current_rev prev_rev
  current_rev=$(echo "$revisions" | sed -n '1p')
  prev_rev=$(echo "$revisions" | sed -n '2p')

  # Timestamp of the previous revision (for the summary table).
  local prev_ts
  prev_ts=$(gcloud run revisions describe "$prev_rev" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --format="value(metadata.creationTimestamp)" 2>/dev/null || echo "unknown")

  echo -e "  current: ${BLUE}$current_rev${RESET}"
  echo -e "  rolling back to: ${BLUE}$prev_rev${RESET} (deployed $prev_ts)"

  if ! gcloud run services update-traffic "$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --to-revisions="${prev_rev}=100" \
      --quiet >/dev/null; then
    echo -e "  ${RED}❌ failed to update traffic${RESET}"
    SUMMARY_ROWS+=("FAIL	$kind	$name	update-traffic failed")
    return 1
  fi

  # Persist state only after the flip succeeded.
  printf '%s\t%s\t%s\n' "$kind" "$name" "$current_rev" >> "$STATE_FILE"
  echo -e "  ${GREEN}✅ rolled back${RESET}"
  SUMMARY_ROWS+=("OK	$kind	$name	prev=$prev_rev deployed=$prev_ts")
}

rollback_job() {
  local name="$1"

  local current_image
  if ! current_image=$(gcloud run jobs describe "$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --format="value(spec.template.spec.template.spec.containers[0].image)" 2>/dev/null); then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: could not describe job (may not exist)${RESET}"
    SUMMARY_ROWS+=("SKIP	job	$name	job not found")
    return 0
  fi

  if [[ -z "$current_image" ]]; then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: no image on job${RESET}"
    SUMMARY_ROWS+=("SKIP	job	$name	no image on job")
    return 0
  fi

  # current_image looks like
  #   us-central1-docker.pkg.dev/<proj>/<repo>/<name>@sha256:abcd...
  # or possibly with a tag instead of a digest. Extract the digest part.
  local current_digest=""
  if [[ "$current_image" == *"@sha256:"* ]]; then
    current_digest="sha256:${current_image##*@sha256:}"
  fi

  local image_repo="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${name}"

  # List images newest-first; pick the most recent digest *before* the
  # currently-deployed one. If the job is pinned by tag rather than digest,
  # we don't have a precise "current" anchor — treat the second-newest as
  # the rollback target and warn.
  local images_json
  if ! images_json=$(gcloud artifacts docker images list "$image_repo" \
      --project="$PROJECT_ID" \
      --sort-by="~UPDATE_TIME" \
      --include-tags \
      --format=json 2>/dev/null); then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: could not list images in Artifact Registry${RESET}"
    SUMMARY_ROWS+=("SKIP	job	$name	AR list failed")
    return 0
  fi

  # Parse digests in newest-first order via python3 (stdlib JSON; same
  # interpreter the smoke test uses).
  local digests
  digests=$(python3 -c '
import json, sys
data = json.loads(sys.stdin.read() or "[]")
for entry in data:
    v = entry.get("version") or ""
    if v.startswith("sha256:"):
        print(v)
' <<< "$images_json")

  if [[ -z "$digests" ]]; then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: no digests found in Artifact Registry${RESET}"
    SUMMARY_ROWS+=("SKIP	job	$name	no digests in AR")
    return 0
  fi

  local prev_digest=""
  if [[ -n "$current_digest" ]]; then
    # Find current in the list, then take the next entry.
    local found_current=0
    while IFS= read -r d; do
      if [[ "$found_current" == "1" ]]; then
        prev_digest="$d"
        break
      fi
      if [[ "$d" == "$current_digest" ]]; then
        found_current=1
      fi
    done <<< "$digests"

    if [[ "$found_current" == "0" ]]; then
      echo -e "  ${YELLOW_BOLD}⚠️  current digest $current_digest not found in AR — falling back to second-newest${RESET}"
      prev_digest=$(echo "$digests" | sed -n '2p')
    fi
  else
    echo -e "  ${YELLOW_BOLD}⚠️  job not pinned by digest; using second-newest digest as rollback target${RESET}"
    prev_digest=$(echo "$digests" | sed -n '2p')
  fi

  if [[ -z "$prev_digest" ]]; then
    echo -e "  ${YELLOW_BOLD}⏭️  skip: no prior digest available${RESET}"
    SUMMARY_ROWS+=("SKIP	job	$name	no prior digest")
    return 0
  fi

  # Timestamp of the previous digest (for the summary table).
  local prev_ts
  prev_ts=$(gcloud artifacts docker images describe \
      "${image_repo}@${prev_digest}" \
      --project="$PROJECT_ID" \
      --format="value(image_summary.upload_time)" 2>/dev/null || echo "unknown")

  echo -e "  current image: ${BLUE}$current_image${RESET}"
  echo -e "  rolling back to: ${BLUE}${image_repo}@${prev_digest}${RESET} (uploaded $prev_ts)"

  if ! gcloud run jobs update "$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --image="${image_repo}@${prev_digest}" \
      --quiet >/dev/null; then
    echo -e "  ${RED}❌ failed to update job image${RESET}"
    SUMMARY_ROWS+=("FAIL	job	$name	jobs update failed")
    return 1
  fi

  # Persist the *original* full image URI so restore is exact.
  printf '%s\t%s\t%s\n' "job" "$name" "$current_image" >> "$STATE_FILE"
  echo -e "  ${GREEN}✅ rolled back${RESET}"
  SUMMARY_ROWS+=("OK	job	$name	prev=${prev_digest:0:19}... uploaded=$prev_ts")
}

for product in "${PRODUCTS[@]}"; do
  for language in "${LANGUAGES[@]}"; do
    if [[ ! -d "$product$language" ]]; then
      continue
    fi

    # Mirror deploy-all-apps.sh:45 — strip trailing slash, swap / for -.
    service_name=$(echo "gcp-sample-apps-${product%/}-$language" | tr '/' '-')

    if is_job_product "$product"; then
      kind="job"
    elif [[ "$product" == "cloud-run-functions/" ]]; then
      kind="function"
    else
      kind="service"
    fi

    echo -e "${YELLOW_BOLD}↩️  Rolling back $kind $service_name${RESET}"

    if [[ "$kind" == "job" ]]; then
      rollback_job "$service_name" || true
    else
      rollback_service "$service_name" "$kind" || true
    fi
  done
done

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

echo ""
echo -e "${YELLOW_BOLD}=== Rollback Summary ===${RESET}"
printf '%-6s  %-9s  %-55s  %s\n' "STATUS" "KIND" "NAME" "DETAIL"
printf '%-6s  %-9s  %-55s  %s\n' "------" "---------" "-------------------------------------------------------" "------"
for row in "${SUMMARY_ROWS[@]}"; do
  IFS=$'\t' read -r status kind name detail <<< "$row"
  printf '%-6s  %-9s  %-55s  %s\n' "$status" "$kind" "$name" "$detail"
done

echo ""
echo -e "State written to ${BLUE}$STATE_FILE${RESET}. Run ${BLUE}./restore-current.sh${RESET} to restore."
