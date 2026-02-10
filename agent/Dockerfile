FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY datadog-agent /app/datadog-agent
RUN chmod +x /app/datadog-agent
CMD ["/app/datadog-agent"]