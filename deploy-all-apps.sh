#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

# This script deploys all apps. Intended to be used internally to verify that all apps are still working.

set -e
cd "$(dirname "$0")"

export PROJECT_ID="datadog-serverless-gcp-demo"
export REGION="us-central1"
export REPO_NAME="gcp-sample-apps"

PRODUCTS=("cloud-run/in-container/" "cloud-run/sidecar/" "cloud-run-functions/" "cloud-run-jobs/")
LANGUAGES=("python" "node" "go" "java" "dotnet" "ruby" "php")

# Color codes
YELLOW_BOLD="\033[1;33m"
RESET="\033[0m"

for product in "${PRODUCTS[@]}"; do
  for language in "${LANGUAGES[@]}"; do
    if [[ ! -d "$product/$language" ]]; then
      echo -e "${YELLOW_BOLD}⏭️  Skipping $language in $product (directory not found)${RESET}"
      continue
    fi

    echo -e "${YELLOW_BOLD}🚀 Deploying $language in $product...${RESET}"
    cd "$product"

    service_name=$(echo "gcp-sample-apps-${product%/}-$language" | tr '/' '-')
    export DD_SERVICE=$service_name
    export GCP_PROJECT_NAME=$DD_SERVICE
    export GCP_FUNCTION_NAME=$DD_SERVICE
    export GCP_JOB_NAME=$DD_SERVICE

    output=$(mktemp)
    if ./build_and_deploy.sh $language > "$output" 2>&1; then
      echo -e "✅ Success"
    else
      echo -e "❌ Failed"
      echo -e "Output:"
      cat "$output"
      exit 1
    fi

    rm "$output"
    cd - > /dev/null
  done
done
