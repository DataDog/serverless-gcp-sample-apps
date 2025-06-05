#! /usr/bin/env bash

set -xe

export TF_VAR_datadog_api_key=${DD_API_KEY:?required but not set}
export TF_VAR_project_name=${GCP_PROJECT_NAME:?required but not set}

export TF_VAR_region="us-east1"
export repository_name="google-cloud-examples"

registry="${TF_VAR_region}-docker.pkg.dev/${TF_VAR_project_name}/${repository_name}"

export TF_VAR_application_name="example-cloud-run-sidecar-python"

docker_tag="$registry/$TF_VAR_application_name:latest"

echo "authenticate with 'google auth login' if necessary"

docker buildx build \
	--platform linux/amd64 \
	--tag $docker_tag \
	--push \
	.

export TF_VAR_docker_image=`docker image inspect --format '{{index .RepoDigests 0}}' $docker_tag`

cd terraform
terraform apply
