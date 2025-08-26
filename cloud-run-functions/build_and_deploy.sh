#!/bin/bash

# Build and deploy script for Cloud Run Functions (Gen 2) apps
# Usage: ./build_and_deploy.sh <language>
# Example: ./build_and_deploy.sh python

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

echo "Deploying $LANGUAGE Cloud Run Function from $PROJECT_PATH"

# Configuration
PROJECT_ID=${PROJECT_ID:?required but not set}
GCP_FUNCTION_NAME=${GCP_FUNCTION_NAME:?required but not set}
DD_SERVICE=${DD_SERVICE:?required but not set}
REGION=${REGION:-us-central1}

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
    php)
        ENTRY_POINT="main"
        RUNTIME="php82"
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
cd "$PROJECT_PATH"
gcloud config set project ${PROJECT_ID}

echo -e "\n====== Deploying Cloud Run Function (Gen 2) ======"

ENV_VARS="DD_SERVICE=$DD_SERVICE"
if [ "$LANGUAGE" = "java" ]; then
    ENV_VARS="$ENV_VARS,JAVA_TOOL_OPTIONS=-javaagent:dd-java-agent.jar"
elif [ "$LANGUAGE" = "dotnet" ]; then
    ENV_VARS="$ENV_VARS,CORECLR_ENABLE_PROFILING=1,CORECLR_PROFILER={846F5F1C-F9AE-4B07-969E-05C26BC060D8},CORECLR_PROFILER_PATH=/workspace/datadog/linux-x64/Datadog.Trace.ClrProfiler.Native.so,DD_DOTNET_TRACER_HOME=/workspace/datadog"
fi

gcloud functions deploy $GCP_FUNCTION_NAME \
  --gen2 \
  --runtime=$RUNTIME \
  --region=$REGION \
  --source=. \
  --entry-point=$ENTRY_POINT \
  --trigger-http \
  --allow-unauthenticated \
  --memory=512Mi \
  --timeout=60s \
  --set-env-vars=$ENV_VARS \
  --project=$PROJECT_ID

echo -e "\n====== Instrumenting with datadog-ci ======"
datadog-ci cloud-run instrument --project=$PROJECT_ID --region=$REGION --service=$GCP_FUNCTION_NAME
