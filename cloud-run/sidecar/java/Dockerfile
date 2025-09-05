# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

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

# Download tracer
ADD 'https://dtdg.co/latest-java-tracer' agent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:agent.jar"

CMD ["./mvnw", "spring-boot:run"]
