const tracer = require('dd-trace').init({
  logInjection: true,
});

const express = require('express');
const app = express();

const { createLogger, format, transports } = require('winston');

const logger = createLogger({
  level: 'info',
  exitOnError: false,
  format: format.json(),
  transports: [
    new transports.Console(),
    new transports.File({ filename: `/shared-volume/logs/app.log` }),
  ]
});

const port = 8080;

app.get('/', (req, res) => {
  logger.info('Hello World!');
  res.status(200).send('Hello World!');
});

app.listen(port, '0.0.0.0', () => {
  logger.info(`Server listening on 0.0.0.0:${port}`);
});

logger.info(`Starting server on port ${port}`);
