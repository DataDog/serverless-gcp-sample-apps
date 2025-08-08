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
  DD_LOGS_ENABLED=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["./main"]
