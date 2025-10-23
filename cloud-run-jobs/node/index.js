// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developed at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

const tracer = require('dd-trace').init({
  logInjection: true,
});

const { createLogger, format, transports } = require('winston');

const logger = createLogger({
  level: 'info',
  exitOnError: false,
  format: format.json(),
  transports: [
    new transports.Console()
  ]
});

const span = tracer.startSpan('my_job');
tracer.scope().activate(span, () => {
  logger.info('Hello world!');
});

span.finish();
