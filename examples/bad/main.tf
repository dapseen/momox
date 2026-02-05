# Example: Non-Compliant Terraform Configuration
# This example intentionally violates policies for testing the risk assessment

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  type = string
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# ============================================================================
# VIOLATION: Storage bucket with multiple security issues
# ============================================================================
resource "google_storage_bucket" "Public_Data" {  # VIOLATION: Uppercase in name
  name     = "my_app_public_data"  # VIOLATION: Underscores in name
  location = "US"
  
  # VIOLATION: Missing uniform_bucket_level_access = true
  uniform_bucket_level_access = false
  
  # VIOLATION: Public access not prevented
  # public_access_prevention = "enforced"  # Missing!
  
  # VIOLATION: No versioning
  # versioning { enabled = true }  # Missing!
  
  # VIOLATION: Missing required labels
  labels = {
    team = "backend"
    # Missing: owner, environment, cost-center, managed-by
  }
}

# ============================================================================
# VIOLATION: Compute instance with security issues
# ============================================================================
resource "google_compute_instance" "web_server" {  # VIOLATION: Underscore in name
  name         = "WebServer01"  # VIOLATION: Uppercase, doesn't follow pattern
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  
  # VIOLATION: Missing shielded_instance_config
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  
  network_interface {
    network = "default"
    
    # VIOLATION: External IP exposed
    access_config {
      # Ephemeral public IP
    }
  }
  
  # VIOLATION: Using default service account
  service_account {
    email  = "${var.project_id}-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]  # VIOLATION: Too broad
  }
  
  # VIOLATION: Missing required labels
  labels = {
    app = "web"
  }
}

# ============================================================================
# VIOLATION: Cloud SQL with security issues
# ============================================================================
resource "google_sql_database_instance" "MainDB" {  # VIOLATION: Uppercase
  name             = "maindb"  # VIOLATION: Doesn't follow naming pattern
  database_version = "POSTGRES_15"
  region           = "us-central1"
  
  settings {
    tier = "db-f1-micro"
    
    ip_configuration {
      ipv4_enabled = true  # VIOLATION: Public IP enabled
      require_ssl  = false  # VIOLATION: SSL not required
      
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"  # VIOLATION: Open to internet
      }
    }
    
    # VIOLATION: No backup configuration
    # backup_configuration { ... }
    
    # VIOLATION: Missing required labels
    user_labels = {
      database = "main"
    }
  }
  
  deletion_protection = false  # VIOLATION: Should be true for data protection
}

# ============================================================================
# VIOLATION: IAM with security issues
# ============================================================================

# VIOLATION: Using primitive role
resource "google_project_iam_member" "editor" {
  project = var.project_id
  role    = "roles/editor"  # VIOLATION: Primitive role
  member  = "user:developer@example.com"
}

# VIOLATION: Creating service account key (should use Workload Identity)
resource "google_service_account" "app" {
  account_id   = "app_service_account"  # VIOLATION: Underscore
  display_name = "App SA"
}

resource "google_service_account_key" "app_key" {  # VIOLATION: SA key creation blocked
  service_account_id = google_service_account.app.name
}

# ============================================================================
# VIOLATION: Firewall with security issues
# ============================================================================
resource "google_compute_firewall" "allow_all_ssh" {
  name    = "allow-all-ssh"
  network = "default"
  
  # VIOLATION: SSH open to internet
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }
  
  source_ranges = ["0.0.0.0/0"]  # VIOLATION: Open to world
}

resource "google_compute_firewall" "allow_all_ports" {
  name    = "allow-all-internal"
  network = "default"
  
  # VIOLATION: All ports open
  allow {
    protocol = "tcp"
    # No ports specified = all ports
  }
  
  source_ranges = ["10.0.0.0/8"]
}

# ============================================================================
# VIOLATION: Blocked resource type
# ============================================================================
# VIOLATION: Using google_project_iam_policy instead of binding/member
# resource "google_project_iam_policy" "project" {
#   project     = var.project_id
#   policy_data = data.google_iam_policy.admin.policy_data
# }

# ============================================================================
# Outputs
# ============================================================================
output "bucket_name" {
  value = google_storage_bucket.Public_Data.name
}

output "sa_key" {
  value     = google_service_account_key.app_key.private_key
  sensitive = true
}
