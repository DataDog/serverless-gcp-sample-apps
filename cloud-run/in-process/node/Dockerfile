FROM node:22

WORKDIR /app

COPY package.json .
RUN npm install

COPY . .

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
ENV NODE_OPTIONS="--require dd-trace/init"

ARG GCP_PROJECT_NAME
ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=${GCP_PROJECT_NAME}
ENV DD_SOURCE=nodejs
ENV DD_LOGS_ENABLED=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["node", "index.js"]
