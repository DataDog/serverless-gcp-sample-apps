# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

FROM node:22-slim

WORKDIR /app

# ca-certificates is required for slim images
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

COPY package.json .
RUN npm install

COPY . .

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
ENV NODE_OPTIONS="--require dd-trace/init"

ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=nodejs \
  DD_LOGS_ENABLED=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["node", "index.js"]
