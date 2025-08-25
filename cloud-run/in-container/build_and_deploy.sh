#!/bin/bash
set -e

# Build and deploy script for in-container Cloud Run apps
# Usage: ./build_and_deploy.sh <language>
# Example: ./build_and_deploy.sh go

if [ $# -ne 1 ]; then
    echo "Usage: $0 <language>"
    echo "Available languages: go, python, node, java, php, ruby, dotnet"
    exit 1
fi

LANGUAGE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/$LANGUAGE"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Language directory '$LANGUAGE' not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$PROJECT_PATH/Dockerfile" ]; then
    echo "Error: No Dockerfile found in $PROJECT_PATH"
    exit 1
fi

echo "Building and deploying $LANGUAGE application from $PROJECT_PATH"

# Configuration
PROJECT_ID=${PROJECT_ID:?required but not set}
GCP_PROJECT_NAME=${GCP_PROJECT_NAME:?required but not set}
DD_SERVICE=${DD_SERVICE:?required but not set}
REPO_NAME=${REPO_NAME:?required but not set}
REGION=${REGION:-us-central1}
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${GCP_PROJECT_NAME}:latest"

# Build
echo -e "\n====== Initializing ======"
cd "$PROJECT_PATH"
gcloud config set project ${PROJECT_ID}

gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo -e "\n====== Building Docker image ======"
docker build --quiet --platform linux/amd64 --build-arg DD_SERVICE=${DD_SERVICE} -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

# Deploy to Cloud Run
echo -e "\n====== Deploying to Cloud Run ======"
gcloud run deploy $GCP_PROJECT_NAME \
  --image=$IMAGE_NAME \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --memory=1024Mi \
  --cpu=1 \
  --port=8080 \
  --set-env-vars=DD_API_KEY=$DD_API_KEY \
  --labels=service=$DD_SERVICE \
  --project=$PROJECT_ID

echo -e "\n====== Deployment completed for $LANGUAGE ======"
