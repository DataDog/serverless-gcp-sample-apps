# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

# The tracer is configured to automatically instrument your application by
# running it with `ddtrace-run` as seen in the `Dockerfile`. Otherwise use
# the `@ddtrace.tracer.wrap` decorator.

import logging
import sys
import os

import datadog
from flask import Flask

# The sidecar exposes a dogstatsd port.
datadog.initialize(
    statsd_host="127.0.0.1",
    statsd_port=8125,
)

app = Flask(__name__)


# Write logs to a file that the sidecar can find. Google Cloud provides a
# mounted directory (`shared-volume`). Create the necessary subdirectories there
# and configure the logger to write to a file in that location.
LOG_FILE = os.environ.get(
    "DD_SERVERLESS_LOG_PATH", "/shared-volume/logs/*.log"
).replace("*.log", "app.log")
print('LOG_FILE: ', LOG_FILE)
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

FORMAT = ('%(asctime)s %(levelname)s [%(name)s] [%(filename)s:%(lineno)d] '
          '[dd.service=%(dd.service)s dd.env=%(dd.env)s dd.version=%(dd.version)s dd.trace_id=%(dd.trace_id)s dd.span_id=%(dd.span_id)s] '
          '- %(message)s')

logging.basicConfig(
    level=logging.INFO,
    format=FORMAT,
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)
logger.level = logging.INFO

app = Flask(__name__)

@app.route('/')
def home():
    # This log will be submitted to Datadog through the shared volume
    logger.info("Hello world!")

    # Serverless apps must use the distribution metric type.
    datadog.statsd.distribution("our-sample-app.sample-metric", 1)
    return 'Hello World!', 200

if __name__ == '__main__':
    logger.info("starting server on port 8080")
    app.run(host='0.0.0.0', port=8080)
