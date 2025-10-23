# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

COPY *.csproj ./
RUN dotnet restore dotnet.csproj

COPY . .
RUN dotnet publish dotnet.csproj -c Release -o out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy the built application
COPY --from=build /app/out .

ENV PORT=8080
EXPOSE 8080

# Copy Datadog serverless-init
COPY --from=datadog/serverless-init:1 / /app/

# Install dependencies for Datadog .NET tracer installation
RUN apt-get update --allow-releaseinfo-change && apt-get install -y --no-install-recommends curl jq && rm -rf /var/lib/apt/lists/*

# Install Datadog .NET tracer
RUN chmod +x /app/dotnet.sh && /app/dotnet.sh

# Datadog configuration
ARG DD_SERVICE
ENV DD_SITE=datadoghq.com \
  DD_SERVICE=${DD_SERVICE} \
  DD_SOURCE=csharp \
  DD_LOGS_ENABLED=true \
  DD_LOGS_INJECTION=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["dotnet", "dotnet.dll"]
