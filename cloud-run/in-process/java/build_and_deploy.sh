#!/bin/bash
set -e

# Configuration
PROJECT_ID=${PROJECT_ID:?required but not set}
GCP_PROJECT_NAME=${GCP_PROJECT_NAME:?required but not set}
REPO_NAME=${REPO_NAME:?required but not set}
REGION="us-central1"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${GCP_PROJECT_NAME}:latest"
PROJECT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Build
echo -e "\n====== Initializing ======"
cd $PROJECT_PATH
gcloud config set project ${PROJECT_ID}

gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo -e "\n====== Building Docker image ======"
docker build --quiet --platform linux/amd64 --build-arg GCP_PROJECT_NAME=${GCP_PROJECT_NAME} -t ${IMAGE_NAME} .
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
  --project=$PROJECT_ID
