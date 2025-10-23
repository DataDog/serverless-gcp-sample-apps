# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

FROM golang:1.24-bookworm

WORKDIR /app

# ca-certificates is required for bookworm images
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o main .

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init

ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=go \
  DD_LOGS_ENABLED=true \
  DD_APPSEC_ENABLED=false

ENTRYPOINT ["/app/datadog-init"]
CMD ["./main"]
