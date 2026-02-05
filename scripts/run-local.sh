#!/bin/bash
# Script to run the Terraform PR Risk Assistant locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Terraform PR Risk Assistant - Local Run ==="
echo ""

# Check for cagent
if ! command -v cagent &> /dev/null; then
    echo "Error: cagent is not installed."
    echo "Install Docker Desktop 4.49+ (includes cagent) or:"
    echo "  brew install cagent"
    exit 1
fi

echo "Cagent version: $(cagent version 2>/dev/null || echo 'unknown')"
echo ""

# Check for required environment variables
check_env() {
    if [ -z "${!1}" ]; then
        echo "Warning: $1 is not set"
        return 1
    fi
    echo "✅ $1 is set"
    return 0
}

echo "=== Checking Environment Variables ==="
MISSING=0
check_env "OPENAI_API_KEY" || MISSING=1

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "Error: OPENAI_API_KEY must be set for the agent and embeddings."
    echo "Get your key at: https://platform.openai.com/api-keys"
    exit 1
fi
echo ""

# Determine the plan file to analyze
PLAN_FILE="${1:-$PROJECT_DIR/examples/sample-tfplan.json}"

if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: Plan file not found: $PLAN_FILE"
    echo ""
    echo "Usage: $0 [path/to/tfplan.json]"
    echo ""
    echo "To generate a plan from your Terraform code:"
    echo "  terraform plan -out=tfplan.binary"
    echo "  terraform show -json tfplan.binary > tfplan.json"
    exit 1
fi

echo "=== Analyzing Plan: $PLAN_FILE ==="
echo ""

# Copy plan to tfplan.json so sub-agents and OPA find it (they expect this filename)
TFPLAN_JSON="$PROJECT_DIR/tfplan.json"
cp "$PLAN_FILE" "$TFPLAN_JSON"
trap "rm -f '$TFPLAN_JSON'" EXIT
echo "Copied plan to $TFPLAN_JSON for agent access"
echo ""

# Build the prompt
PROMPT=$(cat <<EOF
# Terraform Risk Assessment Request

Analyze the Terraform plan for security, compliance, and best practice issues.

## Plan File
The plan is at: tfplan.json (in the project root). All agents should read this file.

## Instructions
1. Read the Terraform plan JSON
2. Identify all resources being created, modified, or deleted
3. Check for security issues:
   - Public access configurations
   - Missing encryption
   - IAM misconfigurations
   - Network security gaps
4. Check for compliance issues:
   - Missing required labels
   - Naming convention violations
   - Unapproved resource types
5. Check for best practices:
   - Deprecated resources
   - Suboptimal configurations
6. Provide a risk score and actionable recommendations

Output a comprehensive assessment report.
EOF
)

# Run cagent
cd "$PROJECT_DIR"
cagent run agents/terraform-pr-assistant.yaml "$PROMPT"
