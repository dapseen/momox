# Example: Compliant Terraform Configuration
# This example demonstrates all required policies being followed

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Local values for consistent naming and labeling
locals {
  project_name = "myapp"
  
  # Standard labels applied to all resources
  common_labels = {
    owner        = "platform-team@company.com"
    environment  = var.environment
    cost-center  = "CC-1234"
    team         = "platform"
    managed-by   = "terraform"
    project      = local.project_name
  }
  
  # Naming prefix
  name_prefix = "${local.project_name}-${var.environment}"
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# ============================================================================
# Storage Bucket - Compliant Configuration
# ============================================================================
resource "google_storage_bucket" "data" {
  name     = "${local.name_prefix}-bucket-data"
  location = var.region
  
  # Security: Uniform bucket-level access
  uniform_bucket_level_access = true
  
  # Security: Prevent public access
  public_access_prevention = "enforced"
  
  # Data protection: Enable versioning
  versioning {
    enabled = true
  }
  
  # Cost management: Lifecycle rules
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  
  # Required labels
  labels = local.common_labels
}

# ============================================================================
# Service Account - Compliant Configuration
# ============================================================================
resource "google_service_account" "app" {
  account_id   = "${local.name_prefix}-sa-app"
  display_name = "Application Service Account"
  description  = "Service account for ${local.project_name} application in ${var.environment}"
}

# IAM binding using predefined role (not primitive)
resource "google_project_iam_member" "app_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# ============================================================================
# Compute Instance - Compliant Configuration
# ============================================================================
resource "google_compute_instance" "web" {
  name         = "${local.name_prefix}-instance-web"
  machine_type = "e2-medium"
  zone         = "${var.region}-a"
  
  # Security: Shielded VM configuration
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-ssd"
    }
  }
  
  network_interface {
    network    = "default"
    subnetwork = "default"
    
    # No external IP - use IAP for access
    # access_config {} # Intentionally omitted
  }
  
  # Use dedicated service account
  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"]
  }
  
  # Enable OS Login for centralized access
  metadata = {
    enable-oslogin = "TRUE"
  }
  
  # Required labels
  labels = local.common_labels
  
  tags = ["web", "internal"]
}

# ============================================================================
# Cloud SQL - Compliant Configuration
# ============================================================================
resource "google_sql_database_instance" "main" {
  name             = "${local.name_prefix}-sql-main"
  database_version = "POSTGRES_15"
  region           = var.region
  
  settings {
    tier = "db-f1-micro"
    
    # Security: Private IP only
    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
      require_ssl     = true
    }
    
    # Data protection: Automated backups
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      
      backup_retention_settings {
        retained_backups = 7
      }
    }
    
    # Maintenance window
    maintenance_window {
      day          = 7  # Sunday
      hour         = 3  # 3 AM
      update_track = "stable"
    }
    
    # Required labels
    user_labels = local.common_labels
  }
  
  deletion_protection = true
}

# ============================================================================
# Pub/Sub - Compliant Configuration
# ============================================================================
resource "google_pubsub_topic" "events" {
  name = "${local.name_prefix}-topic-events"
  
  labels = local.common_labels
  
  message_retention_duration = "604800s"  # 7 days
}

resource "google_pubsub_subscription" "events_processor" {
  name  = "${local.name_prefix}-sub-events-processor"
  topic = google_pubsub_topic.events.name
  
  labels = local.common_labels
  
  ack_deadline_seconds = 60
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.events_dlq.id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_topic" "events_dlq" {
  name   = "${local.name_prefix}-topic-events-dlq"
  labels = local.common_labels
}

# ============================================================================
# Outputs
# ============================================================================
output "bucket_name" {
  description = "Name of the storage bucket"
  value       = google_storage_bucket.data.name
}

output "service_account_email" {
  description = "Email of the application service account"
  value       = google_service_account.app.email
}

output "instance_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.web.name
}

output "sql_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}
