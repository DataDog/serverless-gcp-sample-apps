# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developped at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.37.0"
    }
  }
}

provider "google" {
  project = var.project_name
  region  = var.region
}
