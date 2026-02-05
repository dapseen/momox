# Main Policy Entry Point
# Aggregates all Terraform validation policies

package terraform.validation

import rego.v1

import data.terraform.validation.tags
import data.terraform.validation.naming
import data.terraform.validation.resources
import data.terraform.validation.security

# Aggregate all deny rules from sub-packages
deny contains msg if {
    msg := tags.deny[_]
}

deny contains msg if {
    msg := naming.deny[_]
}

deny contains msg if {
    msg := resources.deny[_]
}

deny contains msg if {
    msg := security.deny[_]
}

# Aggregate all warn rules from sub-packages
warn contains msg if {
    msg := tags.warn[_]
}

warn contains msg if {
    msg := naming.warn[_]
}

warn contains msg if {
    msg := resources.warn[_]
}

warn contains msg if {
    msg := security.warn[_]
}

# Summary helper - counts violations by category
summary := {
    "total_violations": count(deny),
    "total_warnings": count(warn),
    "violations": deny,
    "warnings": warn,
    "compliant": count(deny) == 0,
}
