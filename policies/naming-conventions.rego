# Naming Conventions Policy
# Enforces consistent naming patterns across all GCP resources

package terraform.validation.naming

import rego.v1

# Naming pattern: {project}-{environment}-{resource-type}-{name}
# Examples: 
#   myapp-prod-bucket-uploads
#   myapp-dev-instance-web
#   myapp-staging-sql-main

# Maximum name length for GCP resources (most restrictive)
max_name_length := 63

# Characters that are not allowed in resource names
invalid_chars := ["_", " ", ".", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "+", "="]

# Check for uppercase characters
has_uppercase(name) if {
    lower(name) != name
}

# Check for underscores
has_underscore(name) if {
    contains(name, "_")
}

# Check name length
exceeds_max_length(name) if {
    count(name) > max_name_length
}

# Check if name starts with a letter
starts_with_letter(name) if {
    regex.match(`^[a-z]`, name)
}

# Check if name ends with alphanumeric
ends_with_alphanumeric(name) if {
    regex.match(`[a-z0-9]$`, name)
}

# Deny names with uppercase characters
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    
    name := resource.change.after.name
    name != null
    has_uppercase(name)
    
    msg := sprintf(
        "NAMING_VIOLATION: Resource '%s' name '%s' contains uppercase characters. Use lowercase only",
        [resource.address, name]
    )
}

# Deny names with underscores (should use hyphens)
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    
    name := resource.change.after.name
    name != null
    has_underscore(name)
    
    msg := sprintf(
        "NAMING_VIOLATION: Resource '%s' name '%s' contains underscores. Use hyphens (-) instead",
        [resource.address, name]
    )
}

# Deny names exceeding maximum length
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    
    name := resource.change.after.name
    name != null
    exceeds_max_length(name)
    
    msg := sprintf(
        "NAMING_VIOLATION: Resource '%s' name '%s' exceeds maximum length of %d characters (length: %d)",
        [resource.address, name, max_name_length, count(name)]
    )
}

# Deny names not starting with a letter
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    
    name := resource.change.after.name
    name != null
    not starts_with_letter(name)
    
    msg := sprintf(
        "NAMING_VIOLATION: Resource '%s' name '%s' must start with a lowercase letter",
        [resource.address, name]
    )
}

# Deny names not ending with alphanumeric character
deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] in {"create", "update"}
    
    name := resource.change.after.name
    name != null
    not ends_with_alphanumeric(name)
    
    msg := sprintf(
        "NAMING_VIOLATION: Resource '%s' name '%s' must end with a lowercase letter or number",
        [resource.address, name]
    )
}

# Warning for names not following recommended pattern
warn contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    
    name := resource.change.after.name
    name != null
    
    # Check for recommended pattern: {project}-{env}-{type}-{name}
    # At minimum should have 3 hyphens for 4 segments
    segments := split(name, "-")
    count(segments) < 3
    
    msg := sprintf(
        "NAMING_SUGGESTION: Resource '%s' name '%s' should follow pattern: {project}-{environment}-{type}-{name}",
        [resource.address, name]
    )
}
