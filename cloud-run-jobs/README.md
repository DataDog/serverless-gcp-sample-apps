# Google Cloud Run Jobs

Examples for instrumenting [Google Cloud Run Jobs](https://cloud.google.com/run/docs/create-jobs)
services with Datadog Serverless-Init.

## Available Languages

- [Python](./python/)
- [Node.js](./node/)
- [Go](./go/)
- [Java](./java/)
- [.NET](./dotnet/)

## Quick Deploy

Use the build and deploy script:

```bash
./build_and_deploy.sh <language>
```

### Examples

```bash
# Deploy Python job
./build_and_deploy.sh python

# Deploy Node.js job
./build_and_deploy.sh node
```

### Environment Variables Required

Before running the script, ensure these environment variables are set:

```bash
export PROJECT_ID="your-gcp-project-id"
export GCP_JOB_NAME="your-cloud-run-service-name"
export DD_SERVICE="your-datadog-service-name"
export DD_API_KEY="your-datadog-api-key"
export REGION="us-central1"  # Optional, defaults to us-central1
```
