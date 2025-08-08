FROM openjdk:21-jdk-slim

# ca-certificates is required for slim images
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

WORKDIR /app

# Copy Maven wrapper and dependencies
COPY pom.xml mvnw ./
COPY .mvn .mvn/
RUN ./mvnw dependency:go-offline

# Copy source code
COPY src src/

ENV PORT=8080
EXPOSE 8080

# Download agent and tracer
COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
ADD 'https://dtdg.co/latest-java-tracer' agent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:agent.jar"


# Environment variables
ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=java \
  DD_LOGS_ENABLED=true \
  DD_LOGS_INJECTION=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["./mvnw", "spring-boot:run"]
