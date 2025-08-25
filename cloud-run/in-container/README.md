# Google Cloud Run In-Container Instrumentation

Examples for instrumenting Google Cloud Run services with an in-container serverless-init Datadog agent.

## Available Languages

- [Python](./python)
- [Node.js](./node/)
- [Go](./go/)
- [Java](./java/)
- [.NET](./dotnet/)
- [Ruby](./ruby/)
- [PHP](./php/)

## Quick Deploy

Use the build and deploy script:

```bash
./build_and_deploy.sh <language>
```

### Examples

```shell
# Deploy Go application
./build_and_deploy.sh go

# Deploy Python application
./build_and_deploy.sh python

# Deploy Node.js application
./build_and_deploy.sh node
```

### Environment Variables Required

Before running the script, ensure these environment variables are set:

```bash
export PROJECT_ID="your-gcp-project-id"
export GCP_PROJECT_NAME="your-cloud-run-service-name"
export DD_SERVICE="your-datadog-service-name"
export REPO_NAME="your-artifact-registry-repo"
export DD_API_KEY="your-datadog-api-key"
export REGION="us-central1"  # Optional, defaults to us-central1
```
