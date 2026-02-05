# Approved Resources Policy
# Controls which GCP resource types are allowed to be created

package terraform.validation.resources

import rego.v1

# Approved GCP resource types organized by category
approved_compute := {
    "google_compute_instance",
    "google_compute_instance_template",
    "google_compute_instance_group",
    "google_compute_instance_group_manager",
    "google_compute_disk",
    "google_compute_snapshot",
    "google_compute_image",
}

approved_networking := {
    "google_compute_network",
    "google_compute_subnetwork",
    "google_compute_firewall",
    "google_compute_router",
    "google_compute_router_nat",
    "google_compute_address",
    "google_compute_global_address",
    "google_compute_forwarding_rule",
    "google_compute_target_pool",
    "google_compute_health_check",
    "google_compute_backend_service",
    "google_compute_url_map",
    "google_compute_target_http_proxy",
    "google_compute_target_https_proxy",
    "google_compute_ssl_certificate",
    "google_dns_managed_zone",
    "google_dns_record_set",
}

approved_storage := {
    "google_storage_bucket",
    "google_storage_bucket_object",
    "google_storage_bucket_iam_binding",
    "google_storage_bucket_iam_member",
    "google_storage_notification",
}

approved_database := {
    "google_sql_database_instance",
    "google_sql_database",
    "google_sql_user",
    "google_sql_ssl_cert",
    "google_spanner_instance",
    "google_spanner_database",
    "google_bigtable_instance",
    "google_bigtable_table",
}

approved_container := {
    "google_container_cluster",
    "google_container_node_pool",
    "google_container_registry",
    "google_artifact_registry_repository",
}

approved_serverless := {
    "google_cloud_run_service",
    "google_cloud_run_service_iam_binding",
    "google_cloud_run_service_iam_member",
    "google_cloudfunctions_function",
    "google_cloudfunctions2_function",
    "google_app_engine_application",
    "google_app_engine_standard_app_version",
    "google_app_engine_flexible_app_version",
}

approved_messaging := {
    "google_pubsub_topic",
    "google_pubsub_subscription",
    "google_pubsub_topic_iam_binding",
    "google_pubsub_topic_iam_member",
}

approved_bigdata := {
    "google_bigquery_dataset",
    "google_bigquery_table",
    "google_bigquery_job",
    "google_dataflow_job",
    "google_dataproc_cluster",
    "google_dataproc_job",
}

approved_security := {
    "google_service_account",
    "google_service_account_key",
    "google_project_iam_binding",
    "google_project_iam_member",
    "google_project_iam_custom_role",
    "google_kms_key_ring",
    "google_kms_crypto_key",
    "google_kms_crypto_key_iam_binding",
    "google_secret_manager_secret",
    "google_secret_manager_secret_version",
    "google_secret_manager_secret_iam_binding",
}

approved_monitoring := {
    "google_logging_metric",
    "google_logging_project_sink",
    "google_monitoring_alert_policy",
    "google_monitoring_notification_channel",
    "google_monitoring_uptime_check_config",
    "google_monitoring_dashboard",
}

approved_project := {
    "google_project",
    "google_project_service",
    "google_project_organization_policy",
}

# Combine all approved resources
all_approved := (
    approved_compute |
    approved_networking |
    approved_storage |
    approved_database |
    approved_container |
    approved_serverless |
    approved_messaging |
    approved_bigdata |
    approved_security |
    approved_monitoring |
    approved_project
)

# Resources that require special approval (not blocked, but flagged)
requires_approval := {
    "google_compute_instance",           # VMs should be reviewed
    "google_sql_database_instance",      # Database instances need review
    "google_container_cluster",          # GKE clusters need review
    "google_project_iam_binding",        # IAM changes need review
    "google_service_account_key",        # SA keys need security review
}

# Explicitly blocked resources
blocked_resources := {
    "google_project_iam_policy",         # Use binding/member instead
    "google_folder_iam_policy",          # Use binding/member instead
    "google_organization_iam_policy",    # Use binding/member instead
}

# Check if resource type is approved
is_approved(resource_type) if {
    all_approved[resource_type]
}

# Check if resource type is blocked
is_blocked(resource_type) if {
    blocked_resources[resource_type]
}

# Check if resource requires approval
needs_approval(resource_type) if {
    requires_approval[resource_type]
}

# Deny creation of non-approved resources
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    
    # Only check google_ resources
    startswith(resource.type, "google_")
    
    not is_approved(resource.type)
    not is_blocked(resource.type)  # Blocked resources have their own rule
    
    msg := sprintf(
        "RESOURCE_VIOLATION: Resource type '%s' (address: %s) is not in the approved resources list. Contact Platform team for approval",
        [resource.type, resource.address]
    )
}

# Deny creation of explicitly blocked resources
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    
    is_blocked(resource.type)
    
    msg := sprintf(
        "RESOURCE_BLOCKED: Resource type '%s' (address: %s) is explicitly blocked. Use google_*_iam_binding or google_*_iam_member instead of policy resources",
        [resource.type, resource.address]
    )
}

# Warning for resources that require approval
warn contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    
    needs_approval(resource.type)
    
    msg := sprintf(
        "APPROVAL_REQUIRED: Resource '%s' (type: %s) typically requires Platform team approval. Ensure this has been reviewed",
        [resource.address, resource.type]
    )
}

# Deny destruction of production resources without explicit flag
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "delete"
    
    # Check if resource has production label
    labels := object.get(resource.change.before, "labels", {})
    labels.environment == "prod"
    
    msg := sprintf(
        "DESTRUCTION_BLOCKED: Cannot destroy production resource '%s'. Remove environment=prod label first or get explicit approval",
        [resource.address]
    )
}
