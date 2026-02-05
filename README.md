# Terraform PR Risk Assistant

An AI-powered multi-agent system that analyzes Terraform pull requests for security, compliance, and quality issues using Docker Cagent.

## Overview

This tool helps platform engineers review Terraform PRs by:

- **Security Analysis**: Detecting security misconfigurations in GCP resources
- **Compliance Checks**: Enforcing company policies via OPA/Rego policies
- **Best Practices**: Validating configurations against Terraform and GCP documentation
- **Automated Reviews**: Posting comprehensive summaries as PR comments

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions Workflow                          │
├─────────────────────────────────────────────────────────────────────────┤
│  PR Opened/Updated → terraform plan → OPA validation → Cagent Analysis  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Cagent Multi-Agent System                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Root Orchestrator Agent                        │   │
│  │  • Coordinates analysis across all agents                         │   │
│  │  • Aggregates findings and risk scores                           │   │
│  │  • Posts summary comment to PR                                    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│         ┌──────────────────────────┼──────────────────────────┐         │
│         ▼                          ▼                          ▼         │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐     │
│  │  Terraform  │          │ Compliance  │          │    GCP      │     │
│  │ Docs Agent  │          │   Agent     │          │ Docs Agent  │     │
│  │             │          │             │          │             │     │
│  │ • Provider  │          │ • OPA/Rego  │          │ • GCP best  │     │
│  │   docs      │          │   policies  │          │   practices │     │
│  │ • Module    │          │ • Tag       │          │ • IAM       │     │
│  │   validation│          │   checks    │          │   security  │     │
│  └─────────────┘          └─────────────┘          └─────────────┘     │
│         │                          │                          │         │
│         ▼                          ▼                          ▼         │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐     │
│  │  Terraform  │          │    RAG      │          │   GCP MCP   │     │
│  │ MCP Server  │          │  + Policies │          │   Server    │     │
│  └─────────────┘          └─────────────┘          └─────────────┘     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker Desktop 4.49+ with MCP Gateway enabled
- OpenAI API key
- GitHub repository with Terraform code
- GCP credentials for Terraform operations

### Installation

1. **Copy the agent configuration to your repository:**

```bash
cp -r agents/ /path/to/your/terraform-repo/
cp -r policies/ /path/to/your/terraform-repo/
cp -r docs/ /path/to/your/terraform-repo/
cp -r .github/ /path/to/your/terraform-repo/
```

2. **Configure GitHub Secrets:**

Go to your repository Settings → Secrets and variables → Actions:

| Secret | Description |
|--------|-------------|
| `OPENAI_API_KEY` | OpenAI API key (for agents and embeddings) |
| `GCP_SA_KEY` | GCP service account key JSON |

3. **Enable the workflow:**

The workflow triggers automatically on PRs that modify `.tf` or `.tfvars` files.

### Manual Review

Comment `/review` on any PR to trigger a manual risk assessment.

## Project Structure

```
.
├── agents/
│   └── terraform-pr-assistant.yaml   # Main Cagent configuration
├── policies/
│   ├── main.rego                     # Policy entry point
│   ├── required-tags.rego            # Tag enforcement
│   ├── naming-conventions.rego       # Naming rules
│   ├── approved-resources.rego       # Resource governance
│   └── security-baseline.rego        # Security policies
├── docs/
│   ├── company-standards.md          # Company policies (RAG source)
│   └── mcp-setup.md                  # MCP configuration guide
├── .github/
│   └── workflows/
│       └── terraform-pr-review.yml   # GitHub Actions workflow
├── examples/
│   ├── good/                         # Compliant example
│   ├── bad/                          # Non-compliant example (for testing)
│   └── sample-tfplan.json            # Sample plan for local testing
└── README.md
```

## Agents

### Root Orchestrator

The main coordinator that:
- Parses terraform plan JSON
- Delegates to specialized agents
- Aggregates findings
- Posts PR comments

### Terraform Docs Agent

Validates configurations against HashiCorp documentation:
- Provider resource validation
- Deprecated feature detection
- Module best practices

### Compliance Agent

Enforces company policies using OPA:
- Required labels/tags
- Naming conventions
- Approved resource types
- PR label requirements

### GCP Docs Agent

Provides GCP-specific guidance:
- Security best practices
- IAM recommendations
- CIS Benchmark alignment

## OPA Policies

### Required Tags (`policies/required-tags.rego`)

Ensures resources have mandatory labels:
- `owner`, `environment`, `cost-center`, `team`, `managed-by`

### Naming Conventions (`policies/naming-conventions.rego`)

Enforces naming patterns:
- Pattern: `{project}-{environment}-{type}-{name}`
- Lowercase only, hyphens not underscores

### Approved Resources (`policies/approved-resources.rego`)

Controls allowed resource types:
- Pre-approved resources for self-service
- Resources requiring platform review
- Blocked resources

### Security Baseline (`policies/security-baseline.rego`)

Enforces security requirements:
- Storage: uniform access, no public
- SQL: SSL required, private IP
- Compute: shielded VMs, custom SA
- IAM: no primitive roles
- Network: no open SSH/RDP

## Local Testing

### Test OPA Policies

```bash
# Install OPA
brew install opa

# Run against sample plan
opa eval \
  --input examples/sample-tfplan.json \
  --data policies/ \
  "data.terraform.validation.summary"
```

### Test Cagent Locally

```bash
# Install cagent (comes with Docker Desktop 4.49+)
cagent run agents/terraform-pr-assistant.yaml \
  -p "Analyze the terraform plan in examples/sample-tfplan.json"
```

## Output Example

The agent posts a comment like this on PRs:

```markdown
## 🔍 Terraform PR Risk Assessment

### Risk Score: MEDIUM ⚠️

### Security Findings
| Severity | Resource | Issue | Recommendation |
|----------|----------|-------|----------------|
| HIGH | google_storage_bucket.data | Public access not prevented | Set public_access_prevention = "enforced" |
| HIGH | google_sql_database_instance.main | SSL not required | Set require_ssl = true |
| MEDIUM | google_compute_instance.web | Using default SA | Create dedicated service account |

### Compliance Status
- ❌ Missing required labels: owner, environment, cost-center
- ❌ Naming convention violations found
- ✅ Only approved resource types

### Resource Changes Summary
- 6 resources to create
- 0 resources to modify
- 0 resources to destroy

### Recommendations
1. Add required labels to all resources
2. Enable public_access_prevention on storage buckets
3. Use private IP for Cloud SQL instances
4. Create dedicated service accounts for compute instances
```

## Customization

### Adding Custom Policies

Create a new `.rego` file in `policies/` and import it in `policies/main.rego`:

```rego
package terraform.validation.custom

import rego.v1

deny contains msg if {
    # Your custom policy logic
}
```

### Modifying Company Standards

Edit `docs/company-standards.md` to update the RAG knowledge base with your organization's policies.

### Adjusting Agent Behavior

Modify `agents/terraform-pr-assistant.yaml` to:
- Change models (e.g., use gpt-4-turbo instead of gpt-4o)
- Add/remove sub-agents
- Adjust instructions

## Troubleshooting

### Workflow Not Triggering

- Check that files match the path filter (`**.tf`, `**.tfvars`)
- Verify GitHub Actions is enabled for the repository

### OPA Errors

- Run `opa check policies/` to validate syntax
- Check that all imports are correct

### MCP Connection Issues

- Verify Docker Desktop is running with MCP Gateway enabled
- Check API keys are set correctly
- See `docs/mcp-setup.md` for detailed setup

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with sample terraform plans
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
