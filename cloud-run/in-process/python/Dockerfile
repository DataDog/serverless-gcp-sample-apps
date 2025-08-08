FROM python:3.11-slim

WORKDIR /app

# ca-certificates is required for slim images
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
RUN pip install --target /dd_tracer/python/ ddtrace

COPY . .

ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=python \
  DD_LOGS_ENABLED=true \
  PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/datadog-init"]
CMD ["/dd_tracer/python/bin/ddtrace-run", "python", "app.py"]
