# Google Cloud Run Functions

Examples for instrumenting [Google Cloud Run Functions](https://cloud.google.com/functions)
services with a Datadog sidecar.

## Available Languages

- [Python](./python/)
- [Node.js](./node/)
- [Go](./go/)
- [Java](./java/)
- [.NET](./dotnet/)
- [Ruby](./ruby/)

## Quick Deploy

First, install `datadog-ci`:
```bash
npm install -g @datadog/datadog-ci
```

Use the build and deploy script:

```bash
./build_and_deploy.sh <language>
```

Deployment may fail the first time running the deploy script. This is expected because the shared volume hasn't been configured yet.
Let `datadog-ci instrument` run, then try running the deploy script again.

### Examples

```bash
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
export GCP_FUNCTION_NAME="your-cloud-run-service-name"
export DD_SERVICE="your-datadog-service-name"
export DD_API_KEY="your-datadog-api-key"
export REGION="us-central1"  # Optional, defaults to us-central1
```
