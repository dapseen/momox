# Company Infrastructure Standards and Policies

This document defines the infrastructure standards, policies, and governance rules that must be followed when deploying GCP resources via Terraform.

## Table of Contents

1. [Labeling Standards](#labeling-standards)
2. [Naming Conventions](#naming-conventions)
3. [Resource Governance](#resource-governance)
4. [Security Requirements](#security-requirements)
5. [PR Process Requirements](#pr-process-requirements)
6. [Cost Management](#cost-management)
7. [Compliance Frameworks](#compliance-frameworks)

---

## Labeling Standards

All GCP resources that support labels MUST have the following labels applied:

### Required Labels

| Label Key | Description | Valid Values | Example |
|-----------|-------------|--------------|---------|
| `owner` | Email or team name responsible for the resource | Email address or team name | `platform-team@momox.com` |
| `environment` | Deployment environment | `dev`, `staging`, `prod`, `sandbox`, `test` | `prod` |
| `cost-center` | Financial cost allocation code | Cost center codes as defined by Finance | `CC-1234` |
| `team` | Team that manages this resource | Team names from org chart | `platform`, `data`, `backend` |
| `managed-by` | Tool managing the resource | `terraform` for IaC-managed resources | `terraform` |

### Optional Labels (Recommended)

| Label Key | Description | Example |
|-----------|-------------|---------|
| `project` | Associated project or product name | `customer-portal` |
| `component` | Specific component or service | `api-gateway` |
| `created-date` | Date resource was created | `2025-02-05` |
| `expiry-date` | For temporary resources | `2025-03-05` |
| `data-classification` | Data sensitivity level | `public`, `internal`, `confidential`, `restricted` |

### Label Requirements by Environment

- **Production (`prod`)**: ALL required labels mandatory, no exceptions
- **Staging (`staging`)**: ALL required labels mandatory
- **Development (`dev`)**: `owner`, `environment`, `managed-by` required; others recommended
- **Sandbox (`sandbox`)**: `owner`, `environment` required
- **Test (`test`)**: `owner`, `environment` required

---

## Naming Conventions

### General Pattern

All resource names MUST follow this pattern:

```
{project}-{environment}-{resource-type}-{descriptive-name}
```

### Rules

1. **Lowercase only**: All characters must be lowercase
2. **No underscores**: Use hyphens (`-`) as separators, never underscores (`_`)
3. **No special characters**: Only alphanumeric characters and hyphens allowed
4. **Start with letter**: Names must begin with a lowercase letter
5. **End with alphanumeric**: Names must end with a letter or number
6. **Maximum 63 characters**: GCP enforces this limit on most resources

### Examples

| Resource Type | Good Name | Bad Name |
|---------------|-----------|----------|
| Storage Bucket | `myapp-prod-bucket-uploads` | `myapp_prod_uploads` |
| Compute Instance | `myapp-dev-instance-web-01` | `MyApp-Dev-Web-01` |
| SQL Instance | `myapp-staging-sql-main` | `myapp.staging.sql` |
| Service Account | `myapp-prod-sa-backend` | `myapp_prod_backend_sa` |

### Resource Type Abbreviations

Use these standard abbreviations in names:

| Resource | Abbreviation |
|----------|--------------|
| Storage Bucket | `bucket` |
| Compute Instance | `instance` |
| Cloud SQL | `sql` |
| GKE Cluster | `gke` |
| Cloud Run | `run` |
| Pub/Sub Topic | `topic` |
| Pub/Sub Subscription | `sub` |
| Service Account | `sa` |
| VPC Network | `vpc` |
| Subnet | `subnet` |

---

## Resource Governance

### Approved Resource Types

The Platform team maintains a list of pre-approved GCP resource types. Resources not on this list require explicit approval before deployment.

#### Self-Service (Pre-approved)

These resources can be created without additional approval:

- Storage buckets (with security requirements met)
- Cloud Run services
- Cloud Functions
- Pub/Sub topics and subscriptions
- Secret Manager secrets
- Cloud Scheduler jobs
- Cloud Tasks queues

#### Requires Platform Review

These resources require Platform team approval:

- Compute Engine instances (VM sizing, networking)
- Cloud SQL instances (capacity planning, HA configuration)
- GKE clusters (architecture review)
- VPC networks and subnets (network architecture)
- IAM bindings (security review)
- Load balancers (architecture review)

#### Blocked Resources

These resources are blocked and require escalation:

- `google_project_iam_policy` - Use `iam_binding` or `iam_member` instead
- `google_folder_iam_policy` - Organization-level changes
- `google_organization_iam_policy` - Organization-level changes
- `google_service_account_key` - Use Workload Identity instead

### Production Changes

All changes to production resources require:

1. Approval from at least one Platform team member
2. PR labels: `production`, `infrastructure`
3. Successful terraform plan with no errors
4. Security scan passing
5. Cost estimate review for resources over $100/month

---

## Security Requirements

### Storage Buckets

| Requirement | Configuration | Rationale |
|-------------|---------------|-----------|
| Uniform bucket-level access | `uniform_bucket_level_access = true` | Consistent IAM enforcement |
| Public access prevention | `public_access_prevention = "enforced"` | Prevent accidental exposure |
| Versioning | `versioning { enabled = true }` | Data protection (required for prod) |
| Encryption | CMEK for production data | Data protection compliance |

### Cloud SQL

| Requirement | Configuration | Rationale |
|-------------|---------------|-----------|
| SSL required | `require_ssl = true` | Encrypt data in transit |
| Private IP only | `ipv4_enabled = false` | No public exposure |
| Automated backups | `backup_configuration { enabled = true }` | Data recovery |
| Point-in-time recovery | `binary_log_enabled = true` (MySQL) | Disaster recovery |

### Compute Instances

| Requirement | Configuration | Rationale |
|-------------|---------------|-----------|
| Shielded VM | `shielded_instance_config { ... }` | Secure boot, integrity monitoring |
| Custom service account | Dedicated SA, not default | Least privilege |
| No full cloud-platform scope | Use specific scopes | Least privilege |
| OS Login | `enable-oslogin = true` in metadata | Centralized access control |

### IAM

| Requirement | Details |
|-------------|---------|
| No primitive roles | Use predefined or custom roles, never `roles/owner`, `roles/editor`, `roles/viewer` |
| No public access | Never use `allUsers` or `allAuthenticatedUsers` at project level |
| Workload Identity | Use WIF instead of service account keys |
| Time-bound access | Use IAM conditions for temporary access |

### Network Security

| Requirement | Details |
|-------------|---------|
| No 0.0.0.0/0 for SSH/RDP | Use IAP or VPN for remote access |
| Specific port rules | Avoid firewall rules that allow all ports |
| Private Google Access | Enable for subnets to access GCP services privately |
| VPC Service Controls | Required for sensitive data perimeters |

---

## PR Process Requirements

### Required PR Labels

All infrastructure PRs must have appropriate labels:

| Label | Required When |
|-------|--------------|
| `infrastructure` | All Terraform changes |
| `production` | Changes affecting prod environment |
| `staging` | Changes affecting staging environment |
| `breaking-change` | Destructive changes or major modifications |
| `enhancement` | New features or improvements |
| `bugfix` | Fixing issues |
| `security` | Security-related changes |

### PR Requirements by Environment

#### Production PRs

- [ ] At least 2 approvals (including 1 Platform team member)
- [ ] All CI checks passing
- [ ] Terraform plan shows expected changes
- [ ] Security scan passing
- [ ] Cost impact reviewed
- [ ] Rollback plan documented

#### Staging PRs

- [ ] At least 1 approval
- [ ] All CI checks passing
- [ ] Terraform plan shows expected changes

#### Development PRs

- [ ] At least 1 approval
- [ ] Terraform plan successful

### Destructive Changes

Any PR that includes resource destruction (`-` in terraform plan) must:

1. Have explicit acknowledgment in PR description
2. Include the `breaking-change` label
3. Document impact assessment
4. Have Platform team approval for production

---

## Cost Management

### Cost Thresholds

| Action | Threshold |
|--------|-----------|
| Auto-approve | < $50/month estimated |
| Requires review | $50 - $500/month estimated |
| Requires Finance approval | > $500/month estimated |

### Cost Labels

Use these labels for cost allocation:

- `cost-center`: Primary cost allocation
- `budget-owner`: Budget responsible party
- `project`: Project for cost attribution

### Cost Optimization Requirements

- Use committed use discounts for predictable workloads
- Enable lifecycle policies for storage buckets
- Right-size compute instances
- Use preemptible VMs for fault-tolerant workloads
- Enable autoscaling where appropriate

---

## Compliance Frameworks

### CIS GCP Benchmark

All infrastructure must align with CIS GCP Foundations Benchmark v2.0 recommendations:

- Section 1: IAM
- Section 2: Logging and Monitoring
- Section 3: Networking
- Section 4: Virtual Machines
- Section 5: Storage
- Section 6: Cloud SQL
- Section 7: BigQuery

### SOC 2

For SOC 2 relevant controls, ensure:

- Access controls are enforced via IAM
- Audit logging is enabled
- Encryption at rest and in transit
- Change management via PR process
- Incident response procedures documented

### GDPR (if applicable)

For resources handling EU personal data:

- Data residency in EU regions only
- Encryption with CMEK
- Data retention policies configured
- Access logging enabled
- Data processing agreements in place

---

