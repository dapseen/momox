# Required Tags Policy
# Ensures all GCP resources have mandatory labels for governance and cost allocation

package terraform.validation.tags

import rego.v1

# Required labels that must be present on all taggable resources
required_labels := {"owner", "environment", "cost-center", "team", "managed-by"}

# Valid environment values
valid_environments := {"dev", "staging", "prod", "sandbox", "test"}

# Resources that support labels in GCP
taggable_resources := {
    "google_storage_bucket",
    "google_compute_instance",
    "google_compute_disk",
    "google_sql_database_instance",
    "google_container_cluster",
    "google_container_node_pool",
    "google_pubsub_topic",
    "google_pubsub_subscription",
    "google_bigquery_dataset",
    "google_bigquery_table",
    "google_cloud_run_service",
    "google_cloudfunctions_function",
    "google_cloudfunctions2_function",
    "google_compute_network",
    "google_compute_subnetwork",
    "google_compute_firewall",
    "google_secret_manager_secret",
    "google_kms_key_ring",
    "google_kms_crypto_key",
    "google_service_account",
    "google_project",
}

# Check if a resource type supports labels
is_taggable(resource_type) if {
    taggable_resources[resource_type]
}

# Get labels from resource, handling different label field names
get_labels(resource) := labels if {
    labels := resource.change.after.labels
} else := labels if {
    labels := resource.change.after.tags
} else := {}

# Deny resources missing required labels
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    is_taggable(resource.type)
    
    labels := get_labels(resource)
    missing := required_labels - object.keys(labels)
    count(missing) > 0
    
    msg := sprintf(
        "COMPLIANCE_VIOLATION: Resource '%s' (type: %s) is missing required labels: %v",
        [resource.address, resource.type, missing]
    )
}

# Deny resources with invalid environment label values
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    is_taggable(resource.type)
    
    labels := get_labels(resource)
    env_value := labels.environment
    env_value != null
    not valid_environments[env_value]
    
    msg := sprintf(
        "COMPLIANCE_VIOLATION: Resource '%s' has invalid environment label '%s'. Must be one of: %v",
        [resource.address, env_value, valid_environments]
    )
}

# Deny resources where managed-by is not "terraform"
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    is_taggable(resource.type)
    
    labels := get_labels(resource)
    managed_by := labels["managed-by"]
    managed_by != null
    managed_by != "terraform"
    
    msg := sprintf(
        "COMPLIANCE_VIOLATION: Resource '%s' has managed-by='%s'. Must be 'terraform' for IaC-managed resources",
        [resource.address, managed_by]
    )
}

# Warning for resources without cost-center (softer enforcement)
warn contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    is_taggable(resource.type)
    
    labels := get_labels(resource)
    not labels["cost-center"]
    
    msg := sprintf(
        "COMPLIANCE_WARNING: Resource '%s' should have a 'cost-center' label for billing allocation",
        [resource.address]
    )
}
