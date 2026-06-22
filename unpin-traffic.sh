#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2026-present Datadog, Inc.

# Sends 100% of traffic to the latest revision for every Cloud Run service and
# function in this repo. Run this after rollback-to-previous.sh has pinned
# traffic to specific revisions and you want to restore normal behavior.

set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ID="datadog-serverless-gcp-demo"
REGION="us-central1"

PRODUCTS=("cloud-run/in-container/" "cloud-run/sidecar/" "cloud-run-functions/" "cloud-run-jobs/")
LANGUAGES=("python" "node" "go" "java" "dotnet" "ruby" "php")

# Color codes
GREEN="\033[0;32m"
YELLOW_BOLD="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

SUMMARY_ROWS=()
ANY_FAILURE=0

for product in "${PRODUCTS[@]}"; do
  for language in "${LANGUAGES[@]}"; do
    if [[ ! -d "${product}${language}" ]]; then
      continue
    fi

    # Jobs don't have traffic routing — skip them.
    if [[ "$product" == "cloud-run-jobs/" ]]; then
      continue
    fi

    service_name=$(echo "gcp-sample-apps-${product%/}-${language}" | tr '/' '-')

    echo -e "${YELLOW_BOLD}📌 Unpinning $service_name${RESET}"

    if gcloud run services update-traffic "$service_name" \
        --to-latest \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --quiet 2>&1; then
      echo -e "  ${GREEN}✅ now serving latest revision${RESET}"
      SUMMARY_ROWS+=("OK	$service_name")
    else
      echo -e "  ${RED}❌ failed${RESET}"
      SUMMARY_ROWS+=("FAIL	$service_name")
      ANY_FAILURE=1
    fi
  done
done

echo ""
echo -e "${YELLOW_BOLD}=== Summary ===${RESET}"
for row in "${SUMMARY_ROWS[@]}"; do
  IFS=$'\t' read -r status name <<< "$row"
  printf '%-6s  %s\n' "$status" "$name"
done

echo ""
if [[ "$ANY_FAILURE" == "1" ]]; then
  echo -e "${RED}One or more services failed to unpin.${RESET}" >&2
  exit 1
fi
echo -e "${GREEN}All services unpinned to latest.${RESET}"
