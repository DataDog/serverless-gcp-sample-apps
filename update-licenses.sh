#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.


# Requires:
# - dd-license-attribution (GITHUB_TOKEN must be set)
# - .NET SDK + dotnet-project-licenses (`dotnet tool install -g dotnet-project-licenses`)
# - Ruby + license_finder (`gem install license_finder`)
# - Maven (for Java)
# - Docker (for PHP)

set -e

RUNTIMES=(
  "python"
  "node"
  "go"
  "java"
  "dotnet"
  "ruby"
  "php"
)

RUNTIME_UPDATE_COMMANDS=(
  # python
  "dd-license-attribution https://github.com/DataDog/serverless-gcp-sample-apps/ --no-npm-strategy --no-gopkg-strategy > LICENSE-3rdparty.csv"
  # node
  "dd-license-attribution https://github.com/DataDog/serverless-gcp-sample-apps/ --no-pypi-strategy --no-gopkg-strategy > LICENSE-3rdparty.csv"
  # go
  "dd-license-attribution https://github.com/DataDog/serverless-gcp-sample-apps/ --no-npm-strategy --no-pypi-strategy > LICENSE-3rdparty.csv"
  # java
  "rm -f aggregate-third-party-report.html && mvn -q license:add-third-party"
  # dotnet
  "dotnet-project-licenses -i . -j --outfile licenses.json && jq . licenses.json > licenses_temp.json && mv licenses_temp.json licenses.json"
  # ruby
  "(echo '"component","version","license"'; license_finder report --format csv --quiet) > LICENSE-3rdparty.csv"
  # php. This is hacky and should be improved.
  "docker run --rm composer:2 sh -lc 'composer create-project laravel/laravel:^11.0 /tmp/app --no-interaction >/dev/null && composer licenses -d /tmp/app --format=json --no-interaction' > licenses.json"
)

APP_DIRS=(
  "cloud-run/in-container/"
  "cloud-run/sidecar/"
  "cloud-run-functions/"
)

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "GITHUB_TOKEN is not set. See https://datadoghq.atlassian.net/wiki/spaces/OS/pages/4486988521/dd-license-attribution+CLI+Tool+to+Track+3rd+Party+Dependencies+Copyrights#GitHub-token-for-public-repositories"
  exit 1
fi

for app_dir in "${APP_DIRS[@]}"; do
  for i in "${!RUNTIMES[@]}"; do
    runtime="${RUNTIMES[$i]}"
    if [ -d "$app_dir/$runtime" ]; then
      printf "\033[1;33mUpdating licenses for %s%s\033[0m\n" "$app_dir" "$runtime"
      pushd "$app_dir/$runtime" >/dev/null
      cmd="${RUNTIME_UPDATE_COMMANDS[$i]}"
      eval "$cmd"
      popd >/dev/null
    fi
  done
done
