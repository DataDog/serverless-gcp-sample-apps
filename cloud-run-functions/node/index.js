// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developped at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

const rawLogPath = process.env.DD_SERVERLESS_LOG_PATH;
const LOG_FILE = rawLogPath && rawLogPath !== '' ? rawLogPath.replace('*.log', 'app.log') : '/shared-volume/logs/app.log';
console.log('LOG_FILE: ', LOG_FILE);
const tracer = require('dd-trace').init({
  logInjection: true,
});
const functions = require('@google-cloud/functions-framework');

const { createLogger, format, transports } = require('winston');

const logger = createLogger({
  level: 'info',
  exitOnError: false,
  format: format.json(),
  transports: [
    new transports.Console(),
    new transports.File({ filename: LOG_FILE }),
  ]
});

function handler(req, res) {
  logger.info('Hello world!');
  return res.status(200).send('Hello World!');
}

const handlerWithTrace = tracer.wrap('example-span', handler)
functions.http('main', handlerWithTrace)
module.exports = handlerWithTrace
