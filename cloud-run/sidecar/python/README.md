# Google Cloud Run Python Service with Sidecar Instrumentation

This is a python sample application which demonstrates Datadog instrumentation
with a sidecar container.

This app can be deployed using Terraform with `./build_and_deploy.sh`. The
script will require at least a `DD_API_KEY` and a `GCP_PROJECT_NAME`. It also
requires authentication with `google auth login`.

This app can also be deployed using the `gcloud` tools using the
[yaml](./yaml/) configuration file.
