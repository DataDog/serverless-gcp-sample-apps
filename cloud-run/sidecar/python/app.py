# The tracer is configured to automatically instrument your application by
# running it with `ddtrace-run` as seen in the `Dockerfile`.

import logging
import os

import datadog
from flask import Flask, Response

# The sidecar exposes a dogstatsd port.
datadog.initialize(
    statsd_host="127.0.0.1",
    statsd_port=8125,
)

app = Flask(__name__)


log_filename = os.environ.get(
    "DD_SERVERLESS_LOG_PATH", "/shared-logs/logs/*.log"
).replace("*.log", "app.log")
os.makedirs(os.path.dirname(log_filename), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    filename=log_filename,
)
logger = logging.getLogger(__name__)


@app.route("/")
def home():
    # This log will be submitted to Datadog through the shared volume
    logger.info("Hello!")

    # Serverless apps must use the distributeion metric type.
    datadog.statsd.distribution("our-sample-app.sample-metric", 1)

    return Response(
        '{"msg": "A traced endpoint with custom metrics"}',
        status=200,
        mimetype="application/json",
    )


app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
