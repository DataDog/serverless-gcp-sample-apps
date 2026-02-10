#!/bin/bash

# Build and deploy script for Cloud Run Functions (Gen 2) apps
# Usage: ./build_and_deploy.sh <language>
# Example: ./build_and_deploy.sh python

if [ $# -ne 1 ]; then
    echo "Usage: $0 <language>"
    echo "Available languages: go, python, node, java, ruby, dotnet"
    exit 1
fi

LANGUAGE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/$LANGUAGE"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Language directory '$LANGUAGE' not found in $SCRIPT_DIR"
    exit 1
fi

echo "Deploying $LANGUAGE Cloud Run Function from $PROJECT_PATH"

# Configuration
PROJECT_ID=${PROJECT_ID:?required but not set}
GCP_FUNCTION_NAME=${GCP_FUNCTION_NAME:?required but not set}
DD_SERVICE=${DD_SERVICE:?required but not set}
REPO_NAME=${REPO_NAME:-cloud-run-source-deploy}
REGION=${REGION:-us-central1}

# Optional: Custom agent image configuration
AGENT_IMAGE_NAME=${AGENT_IMAGE_NAME:-""}
AGENT_DIR="$SCRIPT_DIR/../agent"

# Set entry point based on language
case $LANGUAGE in
    python)
        ENTRY_POINT="main"
        RUNTIME="python313"
        ;;
    node)
        ENTRY_POINT="main"
        RUNTIME="nodejs22"
        ;;
    go)
        ENTRY_POINT="main"
        RUNTIME="go124"
        ;;
    java)
        ENTRY_POINT="com.example.App"
        RUNTIME="java21"
        ;;
    dotnet)
        ENTRY_POINT="Main.Function"
        RUNTIME="dotnet8"
        ;;
    ruby)
        ENTRY_POINT="main"
        RUNTIME="ruby32"
        ;;
    *)
        echo "Error: Unsupported language '$LANGUAGE'"
        exit 1
        ;;
esac

# Deploy
echo -e "\n====== Initializing ======"
gcloud config set project ${PROJECT_ID}

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

    gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

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

echo -e "\n====== Deploying Cloud Run Function (Gen 2) ======"

# Check for env file
ENV_VARS_FILE="$PROJECT_PATH/env.yaml"
ENV_VARS_ARGS=""

if [ -f "$ENV_VARS_FILE" ]; then
    echo "Found environment file: $ENV_VARS_FILE"
    ENV_VARS_ARGS="--env-vars-file=$ENV_VARS_FILE"
fi

gcloud run deploy $GCP_FUNCTION_NAME \
  --function=$ENTRY_POINT \
  --region=$REGION \
  --source=. \
  --allow-unauthenticated \
  --memory=512Mi \
  --timeout=60s \
  $ENV_VARS_ARGS \
  --project=$PROJECT_ID \

echo -e "\n====== Instrumenting with datadog-ci ======"
echo "Using sidecar image: $SIDECAR_IMAGE"
datadog-ci cloud-run instrument --project=$PROJECT_ID --region=$REGION --service=$GCP_FUNCTION_NAME --sidecar-image=$SIDECAR_IMAGE
