# Google Cloud Run Python Service with Sidecar Instrumentation

**TODO**: update the links to the public docs once those are available.

This is a python sample application which demonstrates [Datadog](https://docs-staging.datadoghq.com/aleksandr.pasechnik/serverless-gcp-docs-refresh/serverless/google_cloud/google_cloud_run?tab=python) instrumentation with a sidecar container.

This app can be deployed with `./build_and_deploy.sh`. The script will require at least a `DD_API_KEY` and a `GCP_PROJECT_NAME`. It also requires authentication with `google auth login`.
