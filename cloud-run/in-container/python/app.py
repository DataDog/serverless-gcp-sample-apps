# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

from ddtrace import tracer
from flask import Flask
import structlog
import sys

def tracer_injection(logger, log_method, event_dict):
    event_dict.update(tracer.get_log_correlation_context())
    return event_dict

structlog.configure(
    processors=[
        tracer_injection,
        structlog.processors.EventRenamer("msg"),
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.WriteLoggerFactory(file=sys.stdout),
)

logger = structlog.get_logger()

app = Flask(__name__)

@app.route('/')
def hello_world():
    logger.info("Hello world!")
    return 'Hello World!', 200

if __name__ == '__main__':
    logger.info("starting server on port 8080")
    app.run(host='0.0.0.0', port=8080)
