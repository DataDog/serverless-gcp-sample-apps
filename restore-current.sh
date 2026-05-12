#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2026-present Datadog, Inc.

# ----------------------------------------------------------------------------
# ONE-OFF SCRIPT
#
# Companion: rollback-to-previous.sh
#
# Tied to the smoke-test investigation kicked off by commit 5c5c41f (the
# initial smoke_test_apps.py addition). Reads .rollback-state.tsv (produced
# by rollback-to-previous.sh) and flips every recorded service / function /
# job back to its captured original pointer.
#
# Critically, this uses the EXACT revision name / image digest captured at
# rollback time — never --to-latest — because a redeploy mid-investigation
# would otherwise silently restore us to a different state than we measured
# against.
#
# Fails loudly (exits non-zero) if any captured pointer no longer exists;
# the state file is preserved so the operator can investigate and re-run.
# Deletes the state file only after every row was restored successfully.
#
# Safe to delete once the investigation is done, but harmless to keep — we
# may want this dance again.
# ----------------------------------------------------------------------------

set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ID="datadog-serverless-gcp-demo"
REGION="us-central1"

STATE_FILE=".rollback-state.tsv"

# Color codes
GREEN="\033[0;32m"
YELLOW_BOLD="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Summary rows accumulated and printed at the end.
# Format: "status<TAB>kind<TAB>name<TAB>detail"
SUMMARY_ROWS=()
ANY_FAILURE=0

if [[ ! -f "$STATE_FILE" ]]; then
  echo -e "${RED}error: $STATE_FILE not found — nothing to restore.${RESET}" >&2
  exit 1
fi

restore_service() {
  local kind="$1" # "service" or "function"
  local name="$2"
  local target_rev="$3"

  # Sanity-check the captured revision still exists. We'd rather fail loudly
  # than silently flip to something different.
  if ! gcloud run revisions describe "$target_rev" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --format="value(metadata.name)" >/dev/null 2>&1; then
    echo -e "  ${RED}❌ captured revision $target_rev no longer exists — refusing to restore${RESET}"
    SUMMARY_ROWS+=("FAIL	$kind	$name	revision $target_rev missing")
    ANY_FAILURE=1
    return 0
  fi

  echo -e "  restoring to: ${BLUE}$target_rev${RESET}"

  if ! gcloud run services update-traffic "$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --to-revisions="${target_rev}=100" \
      --quiet >/dev/null; then
    echo -e "  ${RED}❌ failed to update traffic${RESET}"
    SUMMARY_ROWS+=("FAIL	$kind	$name	update-traffic failed")
    ANY_FAILURE=1
    return 0
  fi

  echo -e "  ${GREEN}✅ restored${RESET}"
  SUMMARY_ROWS+=("OK	$kind	$name	revision=$target_rev")
}

restore_job() {
  local name="$1"
  local target_image="$2"

  # Sanity-check the captured digest still exists in Artifact Registry.
  if ! gcloud artifacts docker images describe "$target_image" \
      --project="$PROJECT_ID" \
      --format="value(name)" >/dev/null 2>&1; then
    echo -e "  ${RED}❌ captured image $target_image no longer exists in Artifact Registry — refusing to restore${RESET}"
    SUMMARY_ROWS+=("FAIL	job	$name	image missing in AR")
    ANY_FAILURE=1
    return 0
  fi

  echo -e "  restoring to: ${BLUE}$target_image${RESET}"

  if ! gcloud run jobs update "$name" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --image="$target_image" \
      --quiet >/dev/null; then
    echo -e "  ${RED}❌ failed to update job image${RESET}"
    SUMMARY_ROWS+=("FAIL	job	$name	jobs update failed")
    ANY_FAILURE=1
    return 0
  fi

  echo -e "  ${GREEN}✅ restored${RESET}"
  SUMMARY_ROWS+=("OK	job	$name	image=$target_image")
}

while IFS=$'\t' read -r kind name original_pointer; do
  # Skip blank lines defensively.
  if [[ -z "${kind:-}" ]]; then
    continue
  fi

  echo -e "${YELLOW_BOLD}↪️  Restoring $kind $name${RESET}"

  case "$kind" in
    service|function)
      restore_service "$kind" "$name" "$original_pointer"
      ;;
    job)
      restore_job "$name" "$original_pointer"
      ;;
    *)
      echo -e "  ${RED}❌ unknown kind '$kind' — skipping${RESET}"
      SUMMARY_ROWS+=("FAIL	$kind	$name	unknown kind")
      ANY_FAILURE=1
      ;;
  esac
done < "$STATE_FILE"

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

echo ""
echo -e "${YELLOW_BOLD}=== Restore Summary ===${RESET}"
printf '%-6s  %-9s  %-55s  %s\n' "STATUS" "KIND" "NAME" "DETAIL"
printf '%-6s  %-9s  %-55s  %s\n' "------" "---------" "-------------------------------------------------------" "------"
for row in "${SUMMARY_ROWS[@]}"; do
  IFS=$'\t' read -r status kind name detail <<< "$row"
  printf '%-6s  %-9s  %-55s  %s\n' "$status" "$kind" "$name" "$detail"
done

echo ""

if [[ "$ANY_FAILURE" == "1" ]]; then
  echo -e "${RED}One or more restores failed. $STATE_FILE has been preserved — investigate and re-run.${RESET}" >&2
  exit 1
fi

rm -f "$STATE_FILE"
echo -e "${GREEN}All apps restored. Removed $STATE_FILE.${RESET}"
