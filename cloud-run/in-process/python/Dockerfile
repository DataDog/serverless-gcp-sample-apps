FROM python:3.11

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
RUN pip install --target /dd_tracer/python/ ddtrace

COPY . .

ARG GCP_PROJECT_NAME
ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=${GCP_PROJECT_NAME}
ENV DD_SOURCE=python
ENV DD_LOGS_ENABLED=true
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/datadog-init"]
CMD ["/dd_tracer/python/bin/ddtrace-run", "python", "app.py"]
