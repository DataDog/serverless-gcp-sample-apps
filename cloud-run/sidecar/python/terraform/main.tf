resource "google_cloud_run_v2_service" "service" {
  deletion_protection = false

  name     = var.application_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  labels = {
    service = var.dd_service
  }

  template {
    volumes {
      name = var.shared_volume_base_name
      empty_dir {
        medium = "MEMORY"
      }
    }

    timeout = "5s"
    scaling {
      min_instance_count = 1
      max_instance_count = 2
    }

    containers {
      image = var.docker_image

      ports {
        container_port = 8080
      }


      volume_mounts {
        name       = var.shared_volume_base_name
        mount_path = "/${var.shared_volume_base_name}"
      }
      env {
        name  = "DD_SERVERLESS_LOG_PATH"
        value = "/${var.shared_volume_base_name}/logs/*.log"
      }

      depends_on = ["datadog-sidecar"]

      env {
        name  = "DD_SERVICE"
        value = var.dd_service
      }

      # Useful for debugging datadog tooling. Very verbose for general use.
      env {
        name  = "DD_LOG_LEVEL"
        value = "debug"
      }
      env {
        name  = "DD_TRACE_DEBUG"
        value = "true"
      }
    }

    containers {
      name  = "datadog-sidecar"
      image = "gcr.io/datadoghq/serverless-init:latest"

      volume_mounts {
        name       = var.shared_volume_base_name
        mount_path = "/${var.shared_volume_base_name}"
      }
      env {
        name  = "DD_SERVERLESS_LOG_PATH"
        value = "/${var.shared_volume_base_name}/logs/*.log"
      }

      startup_probe {
        tcp_socket {
          port = var.sidecar_startup_probe_port
        }
      }
      env {
        name  = "DD_HEALTH_PORT"
        value = var.sidecar_startup_probe_port
      }

      env {
        name  = "DD_API_KEY"
        value = var.datadog_api_key
      }
      env {
        name  = "DD_SITE"
        value = var.dd_site
      }
      env {
        name  = "DD_SERVICE"
        value = var.dd_service
      }
      env {
        name  = "DD_VERSION"
        value = var.dd_version
      }
      env {
        name  = "DD_ENV"
        value = var.dd_env
      }
      env {
        name  = "DD_TAGS"
        value = var.dd_tags
      }

      # Useful for debugging datadog tooling. Very verbose for general use.
      env {
        name  = "DD_LOG_LEVEL"
        value = "debug"
      }
    }
  }
}

# We make this a publically accessible service for ease of testing.
resource "google_cloud_run_v2_service_iam_binding" "binding" {
  project  = google_cloud_run_v2_service.service.project
  location = google_cloud_run_v2_service.service.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

