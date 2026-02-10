# Google Cloud Functions Gen 1 Deployment Guide

This guide covers deploying and instrumenting Google Cloud Functions (1st generation) with Datadog.

## Prerequisites

1. **Datadog Account**: You need a Datadog API key and know your Datadog site (e.g., `datadoghq.com`)
2. **Datadog Forwarder**: Set up the [Datadog Forwarder](https://docs.datadoghq.com/serverless/google_cloud_run/functions_1st_gen/) to forward logs from Cloud Logging to Datadog
3. **gcloud CLI**: Installed and authenticated

## Environment Variables

Before deploying, set the following environment variables:

```bash
# Required
export PROJECT_ID="your-gcp-project-id"
export GCP_FUNCTION_NAME="your-function-name"
export REGION="us-central1"  # optional, defaults to us-central1

# Datadog Configuration
export DD_API_KEY="your-datadog-api-key"
export DD_SITE="datadoghq.com"  # or datadoghq.eu, us3.datadoghq.com, etc.
export DD_SERVICE="your-service-name"
export DD_ENV="prod"  # or dev, staging, etc.
export DD_VERSION="1.0.0"  # optional
export DD_TAGS="team:serverless,project:sample"  # optional, comma-separated
```

## Deployment

Deploy your function using the provided script:

```bash
./cloud-run-functions/build_and_deploy_gen1.sh python
```

This script will:
1. Deploy the function with `--no-gen2` flag (forces Gen 1)
2. Set the required Datadog environment variables
3. Add a `service` label to correlate traces with metrics
4. Configure the function with proper runtime and entry point

## How Gen 1 Instrumentation Works

### Datadog Libraries
- **datadog-serverless-compat**: Provides serverless compatibility layer
- **ddtrace**: Datadog APM tracer for Python

### Data Flow
1. **Traces**: Sent directly from the function to Datadog via the compat layer
2. **Logs**: Written to stdout → Cloud Logging → Datadog Forwarder → Datadog
3. **Metrics**: Collected via Google Cloud integration (requires setup)

### Code Instrumentation
The function is instrumented with:
```python
from datadog_serverless_compat import start
from ddtrace import tracer, patch_all

start()
patch_all()
```

## Key Differences from Gen 2

| Feature | Gen 1 | Gen 2 |
|---------|-------|-------|
| Deployment | `gcloud functions deploy --no-gen2` | `gcloud run deploy --function` |
| Instrumentation | `datadog-serverless-compat` | Sidecar container |
| Logs | Cloud Logging → Forwarder | Shared volume → Sidecar |
| DogStatsD | Not available by default | Available via sidecar |
| Architecture | Function as a Service | Knative-based |

## Verification

After deployment:

1. **Invoke the function**:
   ```bash
   curl "https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${GCP_FUNCTION_NAME}"
   ```

2. **Check logs** in Cloud Logging:
   ```bash
   gcloud functions logs read $GCP_FUNCTION_NAME --region=$REGION
   ```

3. **View traces** in Datadog APM under the service name you configured

## Troubleshooting

### Logs not appearing in Datadog
- Verify the Datadog Forwarder is properly configured
- Check that logs are appearing in Cloud Logging first
- Ensure DD_API_KEY and DD_SITE are correct

### Traces not appearing
- Check that `datadog-serverless-compat` and `ddtrace` are installed
- Verify DD_SERVICE, DD_ENV are set
- Look for errors in Cloud Logging

### Import errors
- Ensure `requirements.txt` includes all dependencies
- Check the function logs for specific import failures

## References

- [Datadog Gen 1 Functions Documentation](https://docs.datadoghq.com/serverless/google_cloud_run/functions_1st_gen/)
- [Google Cloud Functions Documentation](https://cloud.google.com/functions/docs/1st-gen/concepts/exec)
- [gcloud functions deploy reference](https://cloud.google.com/sdk/gcloud/reference/functions/deploy)
