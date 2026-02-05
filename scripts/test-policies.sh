#!/bin/bash
# Script to test OPA policies locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Terraform PR Risk Assistant - Policy Test ==="
echo ""

# Check for OPA
if ! command -v opa &> /dev/null; then
    echo "Error: OPA is not installed."
    echo "Install with: brew install opa"
    echo "Or download from: https://www.openpolicyagent.org/docs/latest/#running-opa"
    exit 1
fi

echo "OPA version: $(opa version | head -1)"
echo ""

# Check policy syntax
echo "=== Checking Policy Syntax ==="
opa check "$PROJECT_DIR/policies/"
echo "✅ All policies are syntactically valid"
echo ""

# Run against sample plan
echo "=== Running Policies Against Sample Plan ==="
echo ""

SAMPLE_PLAN="$PROJECT_DIR/examples/sample-tfplan.json"

if [ ! -f "$SAMPLE_PLAN" ]; then
    echo "Error: Sample plan not found at $SAMPLE_PLAN"
    exit 1
fi

echo "--- Violations (deny rules) ---"
opa eval \
    --input "$SAMPLE_PLAN" \
    --data "$PROJECT_DIR/policies/" \
    --format pretty \
    "data.terraform.validation.deny"

echo ""
echo "--- Warnings (warn rules) ---"
opa eval \
    --input "$SAMPLE_PLAN" \
    --data "$PROJECT_DIR/policies/" \
    --format pretty \
    "data.terraform.validation.warn"

echo ""
echo "--- Summary ---"
opa eval \
    --input "$SAMPLE_PLAN" \
    --data "$PROJECT_DIR/policies/" \
    --format pretty \
    "data.terraform.validation.summary"

echo ""
echo "=== Test Complete ==="
