# MCP Server Setup Guide

This guide explains how to configure and use the MCP (Model Context Protocol) servers required for the Terraform PR Risk Assistant.

## Overview

The Terraform PR Risk Assistant uses three MCP servers:

| MCP Server | Purpose | Provider |
|------------|---------|----------|
| GitHub Official | Access PRs, post comments, read files | Docker MCP Gateway |
| Terraform MCP Server | Access Terraform provider docs, modules | HashiCorp |
| GCP Documentation | Access Google Cloud documentation | Google Cloud / Community |

## Prerequisites

1. **Docker Desktop 4.49+** with MCP Gateway enabled
2. **API Keys** for your LLM provider (Anthropic, OpenAI, or Google)
3. **GitHub Token** with repo access
4. **GCP Credentials** for Terraform operations

## MCP Server Configuration

### 1. GitHub Official MCP Server

The GitHub MCP server is available through Docker's MCP Gateway.

#### Setup via Docker Desktop

1. Open Docker Desktop
2. Go to **Settings** > **MCP Toolkit**
3. Find `github-official` in the catalog
4. Click **Configure** and add your GitHub token

#### Environment Variables

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

#### Available Tools

- `get_file_contents` - Read file from repository
- `list_commits` - List commits in a repository
- `get_issue` - Get issue/PR details
- `create_issue_comment` - Post comments on issues/PRs
- `search_code` - Search code in repositories
- `get_pull_request` - Get PR details
- `get_pull_request_diff` - Get PR diff
- `create_pull_request_review` - Post PR reviews

### 2. HashiCorp Terraform MCP Server

The Terraform MCP server provides access to Terraform Registry documentation.

#### Installation via Docker

```bash
# Pull the official image
docker pull hashicorp/terraform-mcp-server

# Run as stdio MCP server
docker run -i --rm hashicorp/terraform-mcp-server
```

#### Configuration in Cagent

```yaml
toolsets:
  - type: mcp
    command: docker
    args: ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"]
```

#### Available Tools

| Tool | Description |
|------|-------------|
| `resolveProviderDocID` | Resolve provider documentation ID |
| `getProviderDocs` | Get provider documentation |
| `listProviderResources` | List resources for a provider |
| `listProviderDataSources` | List data sources for a provider |
| `searchModules` | Search Terraform Registry modules |
| `getModuleDetails` | Get module details and inputs |
| `listPolicyLibraries` | List Sentinel policy libraries |

#### Example Usage

```
# Look up GCP storage bucket documentation
Use the Terraform MCP to look up documentation for google_storage_bucket resource
```

### 3. GCP Documentation MCP Server

There are several options for GCP documentation access:

#### Option A: Google Cloud Official MCP (Preview)

Google Cloud provides MCP servers for various services. Check availability at:
https://docs.cloud.google.com/mcp

```yaml
toolsets:
  - type: mcp
    ref: docker:gcp-docs  # When available in Docker MCP catalog
```

#### Option B: Community GCP MCP Server

Use a community-maintained GCP documentation server:

```yaml
toolsets:
  - type: mcp
    command: npx
    args: ["-y", "@anthropic/mcp-gcp-docs"]
    env:
      - "GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json"
```

#### Option C: Web Search Fallback

If no dedicated GCP MCP is available, the agent can use web search:

```yaml
toolsets:
  - type: mcp
    ref: docker:duckduckgo
    instruction: |
      Use DuckDuckGo to search for GCP documentation when needed.
      Prefix searches with "site:cloud.google.com" for official docs.
```

### 4. MCP Gateway Configuration

For Docker MCP Gateway users, configure all servers in Docker Desktop:

1. Open Docker Desktop
2. Navigate to **Settings** > **MCP Toolkit**
3. Configure each server:

```json
{
  "servers": {
    "github-official": {
      "enabled": true,
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "terraform-mcp": {
      "enabled": true,
      "image": "hashicorp/terraform-mcp-server"
    },
    "gcp-docs": {
      "enabled": true,
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/credentials/gcp-key.json"
      },
      "mounts": [
        "/path/to/credentials:/credentials:ro"
      ]
    }
  }
}
```

## Environment Variables

Set these environment variables for the GitHub Actions workflow:

```bash
# LLM Provider (at least one required)
OPENAI_API_KEY=sk-...

# GitHub Access
GITHUB_TOKEN=ghp_...

# GCP Access (for Terraform operations)
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
# Or use individual variables:
GCP_PROJECT_ID=my-project
GCP_REGION=us-central1
```

## GitHub Actions Secrets

Configure these secrets in your repository:

| Secret | Description |
|--------|-------------|
| `OPENAI_API_KEY` | OpenAI API key (for agents and embeddings) |
| `GCP_SA_KEY` | GCP service account key JSON |
| `GITHUB_TOKEN` | Auto-provided by GitHub Actions |

## Testing MCP Connections

### Test GitHub MCP

```bash
cagent run -p "Use GitHub MCP to list the last 5 commits in this repository"
```

### Test Terraform MCP

```bash
cagent run -p "Use Terraform MCP to look up the google_storage_bucket resource documentation"
```

### Test GCP MCP

```bash
cagent run -p "Use GCP MCP to find security best practices for Cloud Storage"
```

## Troubleshooting

### MCP Server Not Responding

1. Check Docker Desktop is running
2. Verify MCP Gateway is enabled
3. Check server logs: `docker logs <container_id>`

### Authentication Errors

1. Verify environment variables are set
2. Check token/key permissions
3. Ensure secrets are configured in GitHub Actions

### Timeout Errors

1. Increase timeout in workflow: `timeout: 900`
2. Check network connectivity
3. Verify MCP server is healthy

## Security Considerations

1. **Never commit secrets** - Use GitHub Secrets or environment variables
2. **Limit token scopes** - Use minimal required permissions
3. **Rotate credentials** - Regularly rotate API keys and tokens
4. **Audit access** - Review who has access to secrets
5. **Use Workload Identity** - Prefer keyless auth for GCP in production
