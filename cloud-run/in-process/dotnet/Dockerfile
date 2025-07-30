FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copy project file and restore dependencies
COPY *.csproj ./
RUN dotnet restore

# Copy source code and build
COPY . ./
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy the built application
COPY --from=build /app/out .

ENV PORT=8080
EXPOSE 8080

# Copy Datadog serverless-init
COPY --from=datadog/serverless-init:1 / /app/

# Install Datadog .NET tracer
RUN chmod +x /app/dotnet.sh && /app/dotnet.sh

# Datadog configuration
ARG GCP_PROJECT_NAME
ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=${GCP_PROJECT_NAME}
ENV DD_SOURCE=csharp
ENV DD_LOGS_ENABLED=true
ENV DD_LOGS_INJECTION=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["dotnet", "dotnet.dll"]
