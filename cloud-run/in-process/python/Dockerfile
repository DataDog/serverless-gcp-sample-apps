# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

FROM python:3.13-slim

WORKDIR /app

# ca-certificates is required for slim images
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init

COPY . .

ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=python \
  DD_LOGS_ENABLED=true \
  PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/datadog-init"]
CMD ["ddtrace-run", "python", "app.py"]
