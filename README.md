# Momox Terraform PR Risk Assistant 

An AI-powered multi-agent system that analyzes Terraform pull requests for security, compliance, and quality issues using Docker Cagent.


## Goal

- Abstract Complexity
- Remove bottleneck
- Help to ship fast
- Standardiz Infra
- Drive compliance and Security 

## Overview

This tool helps platform engineers review Terraform PRs by:

- **Security Analysis**: Detecting security misconfigurations in GCP resources
- **Compliance Checks**: Enforcing company policies and standardization via OPA/Rego policies
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

