FROM python:3.11

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV PORT=8080
ENV PYTHONUNBUFFERED=1
ENV DD_LOGS_ENABLED=true
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
RUN pip install --target /dd_tracer/python/ ddtrace

COPY . .

ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=nhulston-python-test-simple
ENV DD_SOURCE=python

ENTRYPOINT ["/app/datadog-init"]
CMD ["/dd_tracer/python/bin/ddtrace-run", "python", "main.py"]
