# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

# The tracer is configured to automatically instrument your application by
# running it with `ddtrace-run` as seen in the `Dockerfile`. Otherwise use
# the `@ddtrace.tracer.wrap` decorator.

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


# Write logs to a file that the sidecar can find. Google Cloud provides a
# mounted directory (`shared-logs`). Crete the necessary subdirectories there
# and configure the logger to write to a file in that location.
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
