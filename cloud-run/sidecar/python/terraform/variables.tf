# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

# Google Cloud variables

variable "project_name" {
  type     = string
  nullable = false
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "application_name" {
  type    = string
  default = "example-cloud-run-sidecar-python"
}

variable "docker_image" {
  type     = string
  nullable = false
}

# Datadog variables

variable "datadog_api_key" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "dd_service" {
  type    = string
  default = "docs-google-cloud-examples"
}

variable "dd_site" {
  type    = string
  default = "datadoghq.com"
}

variable "dd_version" {
  type    = string
  default = "1"
}

variable "dd_env" {
  type    = string
  default = "dev"
}

variable "dd_tags" {
  type    = string
  default = "deployed-with:terraform"
}

# Other variables

variable "shared_volume_base_name" {
  type    = string
  default = "shared-logs"
}

variable "sidecar_startup_probe_port" {
  type    = string
  default = "9999"
}
