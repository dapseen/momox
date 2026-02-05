# Security Baseline Policy
# Enforces security best practices for GCP resources

package terraform.validation.security

import rego.v1

# ============================================================================
# Storage Security
# ============================================================================

# Deny public storage buckets
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    resource.change.actions[_] in {"create", "update"}
    
    # Check for public access prevention
    pap := resource.change.after.public_access_prevention
    pap != "enforced"
    
    msg := sprintf(
        "SECURITY_VIOLATION: Storage bucket '%s' must have public_access_prevention = 'enforced' to prevent public access",
        [resource.address]
    )
}

# Require uniform bucket-level access
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    resource.change.actions[_] in {"create", "update"}
    
    ubla := resource.change.after.uniform_bucket_level_access
    ubla != true
    
    msg := sprintf(
        "SECURITY_VIOLATION: Storage bucket '%s' must have uniform_bucket_level_access = true for consistent IAM policies",
        [resource.address]
    )
}

# Recommend versioning for data buckets
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    resource.change.actions[_] == "create"
    
    versioning := object.get(resource.change.after, "versioning", [])
    count(versioning) == 0
    
    msg := sprintf(
        "SECURITY_WARNING: Storage bucket '%s' should enable versioning for data protection",
        [resource.address]
    )
}

# ============================================================================
# Database Security
# ============================================================================

# Require SSL for Cloud SQL
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    resource.change.actions[_] in {"create", "update"}
    
    settings := resource.change.after.settings[0]
    ip_config := object.get(settings, "ip_configuration", {})
    require_ssl := object.get(ip_config, "require_ssl", false)
    require_ssl != true
    
    msg := sprintf(
        "SECURITY_VIOLATION: Cloud SQL instance '%s' must have require_ssl = true",
        [resource.address]
    )
}

# Deny public IP for Cloud SQL
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    resource.change.actions[_] in {"create", "update"}
    
    settings := resource.change.after.settings[0]
    ip_config := object.get(settings, "ip_configuration", {})
    ipv4_enabled := object.get(ip_config, "ipv4_enabled", false)
    ipv4_enabled == true
    
    msg := sprintf(
        "SECURITY_VIOLATION: Cloud SQL instance '%s' should not have public IP (ipv4_enabled = true). Use private IP with VPC",
        [resource.address]
    )
}

# Require automated backups for Cloud SQL
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    resource.change.actions[_] == "create"
    
    settings := resource.change.after.settings[0]
    backup_config := object.get(settings, "backup_configuration", {})
    enabled := object.get(backup_config, "enabled", false)
    enabled != true
    
    msg := sprintf(
        "SECURITY_WARNING: Cloud SQL instance '%s' should have automated backups enabled",
        [resource.address]
    )
}

# ============================================================================
# Compute Security
# ============================================================================

# Require shielded VM for compute instances
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    resource.change.actions[_] in {"create", "update"}
    
    shielded := object.get(resource.change.after, "shielded_instance_config", [])
    count(shielded) == 0
    
    msg := sprintf(
        "SECURITY_VIOLATION: Compute instance '%s' must have shielded_instance_config enabled",
        [resource.address]
    )
}

# Deny default service account for compute instances
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    resource.change.actions[_] in {"create", "update"}
    
    sa := resource.change.after.service_account[0]
    email := sa.email
    contains(email, "-compute@developer.gserviceaccount.com")
    
    msg := sprintf(
        "SECURITY_VIOLATION: Compute instance '%s' should not use the default compute service account. Create a dedicated service account",
        [resource.address]
    )
}

# Deny instances with full cloud-platform scope
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    resource.change.actions[_] in {"create", "update"}
    
    sa := resource.change.after.service_account[0]
    scopes := sa.scopes
    scopes[_] == "https://www.googleapis.com/auth/cloud-platform"
    
    msg := sprintf(
        "SECURITY_VIOLATION: Compute instance '%s' should not use 'cloud-platform' scope. Use specific scopes instead",
        [resource.address]
    )
}

# ============================================================================
# IAM Security
# ============================================================================

# Deny primitive roles (Owner, Editor, Viewer at project level)
primitive_roles := {
    "roles/owner",
    "roles/editor", 
    "roles/viewer",
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in {"google_project_iam_binding", "google_project_iam_member"}
    resource.change.actions[_] in {"create", "update"}
    
    role := resource.change.after.role
    primitive_roles[role]
    
    msg := sprintf(
        "SECURITY_VIOLATION: IAM binding '%s' uses primitive role '%s'. Use predefined or custom roles with least privilege",
        [resource.address, role]
    )
}

# Deny allUsers or allAuthenticatedUsers bindings
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_project_iam_member"
    resource.change.actions[_] in {"create", "update"}
    
    member := resource.change.after.member
    member in {"allUsers", "allAuthenticatedUsers"}
    
    msg := sprintf(
        "SECURITY_VIOLATION: IAM member '%s' grants access to '%s'. This is not allowed for project-level IAM",
        [resource.address, member]
    )
}

# Deny service account key creation (prefer workload identity)
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_service_account_key"
    resource.change.actions[_] == "create"
    
    msg := sprintf(
        "SECURITY_VIOLATION: Service account key '%s' should not be created. Use Workload Identity or other keyless authentication methods",
        [resource.address]
    )
}

# ============================================================================
# Network Security
# ============================================================================

# Deny overly permissive firewall rules (0.0.0.0/0 source)
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_compute_firewall"
    resource.change.actions[_] in {"create", "update"}
    
    # Check if direction is INGRESS (default)
    direction := object.get(resource.change.after, "direction", "INGRESS")
    direction == "INGRESS"
    
    source_ranges := object.get(resource.change.after, "source_ranges", [])
    source_ranges[_] == "0.0.0.0/0"
    
    # Allow if only for health checks or specific ports
    allowed := resource.change.after.allow[_]
    ports := object.get(allowed, "ports", [])
    
    # Block if SSH (22) or RDP (3389) is open to internet
    ports[_] in {"22", "3389"}
    
    msg := sprintf(
        "SECURITY_VIOLATION: Firewall rule '%s' allows SSH/RDP from 0.0.0.0/0. Use IAP or VPN for remote access",
        [resource.address]
    )
}

# Warn about firewall rules allowing all ports
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_compute_firewall"
    resource.change.actions[_] in {"create", "update"}
    
    allowed := resource.change.after.allow[_]
    ports := object.get(allowed, "ports", [])
    count(ports) == 0  # Empty ports means all ports
    
    msg := sprintf(
        "SECURITY_WARNING: Firewall rule '%s' allows all ports. Consider restricting to specific ports",
        [resource.address]
    )
}

# ============================================================================
# Encryption
# ============================================================================

# Require customer-managed encryption for sensitive resources
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type in {"google_storage_bucket", "google_bigquery_dataset"}
    resource.change.actions[_] == "create"
    
    labels := object.get(resource.change.after, "labels", {})
    labels.environment == "prod"
    
    # Check for CMEK
    encryption := object.get(resource.change.after, "encryption", [])
    count(encryption) == 0
    
    msg := sprintf(
        "SECURITY_WARNING: Production resource '%s' should use customer-managed encryption keys (CMEK)",
        [resource.address]
    )
}

# ============================================================================
# Logging and Monitoring
# ============================================================================

# Warn if audit logging might not be configured
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_project"
    resource.change.actions[_] == "create"
    
    msg := sprintf(
        "SECURITY_REMINDER: Ensure audit logging is configured for project '%s' via google_project_iam_audit_config",
        [resource.address]
    )
}
