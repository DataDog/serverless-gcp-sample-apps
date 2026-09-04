# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

FROM php:8.5.10-cli

WORKDIR /app

# ca-certificates is required for HTTPS, curl for tracer install
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl

# Install Datadog PHP tracer
RUN curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php \
    && php datadog-setup.php --php-bin=all \
    && rm datadog-setup.php

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init

COPY . .

ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=php \
  DD_LOGS_ENABLED=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["php", "app.php"]
