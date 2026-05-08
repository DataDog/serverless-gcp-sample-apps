#!/bin/bash

# Build and deploy script for Cloud Functions (Gen 1 / v1)
# Usage: ./build_and_deploy_gen1.sh <language>
# Example: ./build_and_deploy_gen1.sh python

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

echo "Deploying $LANGUAGE Cloud Function (Gen 1) from $PROJECT_PATH"

# Configuration
PROJECT_ID=${PROJECT_ID:?required but not set}
GCP_FUNCTION_NAME=${GCP_FUNCTION_NAME:?required but not set}
DD_SERVICE=${DD_SERVICE:?required but not set}
REGION=${REGION:-us-central1}

# Set entry point and runtime based on language
case $LANGUAGE in
    python)
        ENTRY_POINT="main"
        RUNTIME="python311"
        TRIGGER="--trigger-http"
        ;;
    node)
        ENTRY_POINT="main"
        RUNTIME="nodejs22"
        TRIGGER="--trigger-http"
        ;;
    go)
        ENTRY_POINT="main"
        RUNTIME="go124"
        TRIGGER="--trigger-http"
        ;;
    java)
        ENTRY_POINT="com.example.App"
        RUNTIME="java17"
        TRIGGER="--trigger-http"
        ;;
    dotnet)
        ENTRY_POINT="Main.Function"
        RUNTIME="dotnet8"
        TRIGGER="--trigger-http"
        ;;
    ruby)
        ENTRY_POINT="main"
        RUNTIME="ruby32"
        TRIGGER="--trigger-http"
        ;;
    *)
        echo "Error: Unsupported language '$LANGUAGE'"
        exit 1
        ;;
esac

# Deploy
echo -e "\n====== Initializing ======"
gcloud config set project ${PROJECT_ID}

cd "$PROJECT_PATH"

echo -e "\n====== Deploying Cloud Function (Gen 1) ======"

# Generate env.yaml with substituted values (gcloud does not expand shell vars in yaml files)
DD_API_KEY=${DD_API_KEY:?required but not set}
DD_SITE=${DD_SITE:?required but not set}
GENERATED_ENV_YAML="$PROJECT_PATH/.env.gen1.yaml"

cat > "$GENERATED_ENV_YAML" <<EOF
DD_API_KEY: "${DD_API_KEY}"
DD_SITE: "${DD_SITE}"
DD_SERVICE: "${DD_SERVICE}"
EOF
[ -n "$DD_ENV" ]               && echo "DD_ENV: \"${DD_ENV}\""               >> "$GENERATED_ENV_YAML"
[ -n "$DD_VERSION" ]           && echo "DD_VERSION: \"${DD_VERSION}\""       >> "$GENERATED_ENV_YAML"
[ -n "$DD_TAGS" ]              && echo "DD_TAGS: \"${DD_TAGS}\""             >> "$GENERATED_ENV_YAML"
[ -n "$DD_PROFILING_ENABLED" ] && echo "DD_PROFILING_ENABLED: \"${DD_PROFILING_ENABLED}\"" >> "$GENERATED_ENV_YAML"
[ -n "$DD_LOG_LEVEL" ]         && echo "DD_LOG_LEVEL: \"${DD_LOG_LEVEL}\""   >> "$GENERATED_ENV_YAML"
[ -n "$DD_TRACE_DEBUG" ]       && echo "DD_TRACE_DEBUG: \"${DD_TRACE_DEBUG}\"" >> "$GENERATED_ENV_YAML"

# Language-specific env vars
case $LANGUAGE in
    python)
        echo 'PYTHONUNBUFFERED: "1"' >> "$GENERATED_ENV_YAML"
        ;;
    java)
        echo 'JAVA_TOOL_OPTIONS: "-javaagent:dd-serverless-compat-java-agent.jar"' >> "$GENERATED_ENV_YAML"
        echo 'DD_SERVERLESS_LOG_PATH: "/tmp/*.log"' >> "$GENERATED_ENV_YAML"
        ;;
esac

ENV_VARS_ARGS="--env-vars-file=$GENERATED_ENV_YAML"

gcloud functions deploy $GCP_FUNCTION_NAME \
  --no-gen2 \
  --entry-point=$ENTRY_POINT \
  --runtime=$RUNTIME \
  --region=$REGION \
  --source=. \
  --allow-unauthenticated \
  --memory=512MB \
  --timeout=60s \
  $TRIGGER \
  $ENV_VARS_ARGS \
  --project=$PROJECT_ID

echo -e "\n====== Adding service label for trace correlation ======"
# Add service label to correlate traces with metrics
gcloud functions deploy $GCP_FUNCTION_NAME \
  --no-gen2 \
  --runtime=$RUNTIME \
  --region=$REGION \
  --update-labels=service=$DD_SERVICE \
  --allow-unauthenticated \
  --project=$PROJECT_ID

echo -e "\n====== Deployment Complete ======"
echo "Function URL: https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${GCP_FUNCTION_NAME}"
echo ""
echo "Important: Make sure you have configured the Datadog Forwarder to forward logs from Cloud Logging to Datadog."
echo "See: https://docs.datadoghq.com/serverless/google_cloud_run/functions_1st_gen/"
