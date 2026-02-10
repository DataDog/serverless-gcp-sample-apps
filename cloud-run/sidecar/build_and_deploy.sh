#!/bin/bash
set -e

# Build and deploy script for sidecar Cloud Run apps
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

# Optional: Custom agent image configuration
AGENT_IMAGE_NAME=${AGENT_IMAGE_NAME:-""}
AGENT_DIR="$SCRIPT_DIR/../../agent"

# Build
echo -e "\n====== Initializing ======"
gcloud config set project ${PROJECT_ID}

gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build custom agent image if AGENT_IMAGE_NAME is set
if [ -n "$AGENT_IMAGE_NAME" ]; then
    echo -e "\n====== Building custom agent image ======"
    if [ ! -d "$AGENT_DIR" ]; then
        echo "Error: Agent directory not found at $AGENT_DIR"
        exit 1
    fi
    if [ ! -f "$AGENT_DIR/datadog-agent" ]; then
        echo "Error: datadog-agent binary not found at $AGENT_DIR/datadog-agent"
        echo "Please place your dev build of datadog-agent in the agent/ directory"
        exit 1
    fi
    cd "$AGENT_DIR"
    AGENT_IMAGE_FULL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${AGENT_IMAGE_NAME}:latest"
    echo "Building agent image: $AGENT_IMAGE_FULL"
    docker build --quiet --platform linux/amd64 -t ${AGENT_IMAGE_FULL} .
    docker push ${AGENT_IMAGE_FULL}
    SIDECAR_IMAGE="$AGENT_IMAGE_FULL"
else
    SIDECAR_IMAGE="datadog/serverless-init:1"
fi

cd "$PROJECT_PATH"

echo -e "\n====== Building Docker image ======"
docker build --quiet --platform linux/amd64 -t ${IMAGE_NAME} .
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
  --labels=service=$DD_SERVICE \
  --project=$PROJECT_ID

echo -e "\n====== Instrumenting with datadog-ci ======"
echo "Using sidecar image: $SIDECAR_IMAGE"
datadog-ci cloud-run instrument --project=$PROJECT_ID --region=$REGION --service=$GCP_PROJECT_NAME --sidecar-image=$SIDECAR_IMAGE
