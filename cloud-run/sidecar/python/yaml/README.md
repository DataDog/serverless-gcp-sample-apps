# Serverless GCP Cloud Run Sidecar YAML Configuration

The [service.yaml](./service.yaml) file is an example of the [Google Cloud Run Service YAML](https://cloud.google.com/run/docs/reference/yaml/v1) configuration file. Some of the values have been redacted and replace with `<SOME_VALUE>` placeholders.

## Key Values
- `SERVICE_NAME`: set in multiple spots and used for the service name in the datadog view.
- `APP_NAME`: the name of the Cloud Run Service
- `DOCKER_IMAGE`: the docker image to deploy
- `DD_API_KEY`: the Datadog API Key
- `LOCATION`: the Google Cloud location to use, for example `us-central1`.

## Usage

The updated yaml file with its placeholders filled in can be deployed to google cloud using the [gcloud run services replace](https://cloud.google.com/sdk/gcloud/reference/run/services/replace) command:

```bash
gcloud run services replace service-filled-in.yaml
```
