# Serverless Google Cloud Sample Apps

This repository contains sample apps for various serverless Google Cloud
environments. These samples can be used in conjunction with our official
documentation to correctly set up Datadog instrumentation for your serverless
applications.

- [Google Cloud Run](./cloud-run/)
    - [Sidecar instrumentation](./cloud-run/sidecar/)
        - [Python](./cloud-run/sidecar/python/)
        - [Node.js](./cloud-run/sidecar/node/)
        - [Go](./cloud-run/sidecar/go/)
        - [Java](./cloud-run/sidecar/java/)
        - [.NET](./cloud-run/sidecar/dotnet/)
        - [Ruby](./cloud-run/sidecar/ruby/)
        - [PHP](./cloud-run/sidecar/php/)
    - [In-Container instrumentation](./cloud-run/in-container/)
        - [Python](./cloud-run/in-container/python/)
        - [Node.js](./cloud-run/in-container/node/)
        - [Go](./cloud-run/in-container/go/)
        - [Java](./cloud-run/in-container/java/)
        - [.NET](./cloud-run/in-container/dotnet/)
        - [Ruby](./cloud-run/in-container/ruby/)
        - [PHP](./cloud-run/in-container/php/)
- [Google Cloud Run Functions (v2)](./cloud-run-functions/)
    - [Python](./cloud-run-functions/python/)
    - [Node.js](./cloud-run-functions/node/)
    - [Go](./cloud-run-functions/go/)
    - [Java](./cloud-run-functions/java/)
    - [.NET](./cloud-run-functions/dotnet/)
    - [Ruby](./cloud-run-functions/ruby/)
- [Google Cloud Run Jobs (v2)](./cloud-run-jobs/)
    - [Python](./cloud-run-jobs/python/)
    - [Node.js](./cloud-run-jobs/node/)
    - [Go](./cloud-run-jobs/go/)
    - [Java](./cloud-run-jobs/java/)
    - [.NET](./cloud-run-jobs/dotnet/)

To update licenses, run the `./update-licenses.sh` script. View the comments in the README to see what dependencies need to be installed first.

## Smoke test

After deploying the sample apps, run `./smoke_test_apps.py` to verify that each
service is reachable and that its telemetry is landing in Datadog. The script
invokes every app in parallel, then queries the Datadog API for spans, logs,
and (for the two Python apps that emit it) the `our-sample-app.sample-metric`
custom metric.

Required environment variables:

- `DD_API_KEY` — Datadog API key
- `DD_APP_KEY` — Datadog application key

Optional environment variables (CLI flags also available; see `--help`):

- `DD_SITE` (default `datadoghq.com`)
- `PROJECT_ID` (default `datadog-serverless-gcp-demo`)
- `REGION` (default `us-central1`)
- `SMOKE_DELAY` — seconds to wait between invocation and Datadog query (default `90`)
- `SMOKE_INVOCATIONS` — HTTP requests per Cloud Run service (default `3`)

Filter which apps to test with `--app`, `--product`, and `--language` (each
repeatable, comma-separated, and `--app` supports globs).
