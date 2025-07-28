#!/bin/bash

# Test script to verify environment variable handling
echo "=== Testing Environment Variable Handling ==="

# Simulate workflow inputs
echo "Testing empty input (GitHub Actions default behavior):"
WORKFLOW_INPUT=""
echo "WORKFLOW_INPUT: '${WORKFLOW_INPUT}'"
echo "Length: ${#WORKFLOW_INPUT}"

if [ "${WORKFLOW_INPUT}" = "true" ] || [ -z "${WORKFLOW_INPUT}" ]; then
    export APPLY_EXPERIMENTAL_PATCHES="true"
    echo "✅ Would apply experimental patches (empty input uses default)"
else
    export APPLY_EXPERIMENTAL_PATCHES="false"
    echo "❌ Would NOT apply experimental patches"
fi

echo "Final APPLY_EXPERIMENTAL_PATCHES: '${APPLY_EXPERIMENTAL_PATCHES}'"

echo ""
echo "Testing explicit 'true' input:"
WORKFLOW_INPUT="true"
echo "WORKFLOW_INPUT: '${WORKFLOW_INPUT}'"

if [ "${WORKFLOW_INPUT}" = "true" ] || [ -z "${WORKFLOW_INPUT}" ]; then
    export APPLY_EXPERIMENTAL_PATCHES="true"
    echo "✅ Would apply experimental patches (explicit true)"
else
    export APPLY_EXPERIMENTAL_PATCHES="false"
    echo "❌ Would NOT apply experimental patches"
fi

echo "Final APPLY_EXPERIMENTAL_PATCHES: '${APPLY_EXPERIMENTAL_PATCHES}'"

echo ""
echo "Testing 'false' input:"
WORKFLOW_INPUT="false"
echo "WORKFLOW_INPUT: '${WORKFLOW_INPUT}'"

if [ "${WORKFLOW_INPUT}" = "true" ] || [ -z "${WORKFLOW_INPUT}" ]; then
    export APPLY_EXPERIMENTAL_PATCHES="true"
    echo "✅ Would apply experimental patches"
else
    export APPLY_EXPERIMENTAL_PATCHES="false"
    echo "❌ Would NOT apply experimental patches (explicit false)"
fi

echo "Final APPLY_EXPERIMENTAL_PATCHES: '${APPLY_EXPERIMENTAL_PATCHES}'"
