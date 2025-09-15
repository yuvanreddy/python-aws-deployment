#!/bin/bash

# verify_python.sh - Verify Python installation on EC2 instances

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Python Installation Verification Script"
echo "========================================="

# Check if instance ID is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <instance-id>${NC}"
    echo "Getting all running instances with PythonDeployment tag..."
    
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=PythonDeployment" \
                 "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)
else
    INSTANCES=$1
fi

if [ -z "$INSTANCES" ]; then
    echo -e "${RED}No instances found${NC}"
    exit 1
fi

# Function to check Python on an instance
check_python() {
    local instance_id=$1
    echo ""
    echo "Checking instance: $instance_id"
    echo "-----------------------------------"
    
    # Create verification command
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=[
            "echo \"=== Python Version ===\"",
            "python3 --version || echo \"Python3 not found\"",
            "echo \"\"",
            "echo \"=== Pip Version ===\"", 
            "pip3 --version || echo \"Pip3 not found\"",
            "echo \"\"",
            "echo \"=== Installed Packages ===\"",
            "pip3 list 2>/dev/null | head -20 || echo \"No packages found\"",
            "echo \"\"",
            "echo \"=== Python Path ===\"",
            "which python3 || echo \"Python3 path not found\"",
            "echo \"\"",
            "echo \"=== Test Import ===\"",
            "python3 -c \"import sys; print(f\"Python {sys.version}\")\" || echo \"Failed to run Python\""
        ]' \
        --output text \
        --query 'Command.CommandId')
    
    echo "Command sent, waiting for results..."
    sleep 5
    
    # Get command status
    STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$instance_id" \
        --query 'Status' \
        --output text 2>/dev/null || echo "Failed")
    
    if [ "$STATUS" == "Success" ]; then
        # Get command output
        OUTPUT=$(aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$instance_id" \
            --query 'StandardOutputContent' \
            --output text)
        
        echo -e "${GREEN}✓ Python verification successful${NC}"
        echo "$OUTPUT"
    else
        echo -e "${RED}✗ Python verification failed${NC}"
        ERROR=$(aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$instance_id" \
            --query 'StandardErrorContent' \
            --output text 2>/dev/null || echo "No error details available")
        echo "Error: $ERROR"
    fi
}

# Check Python on all instances
for instance in $INSTANCES; do
    check_python "$instance"
done

echo ""
echo "========================================="
echo "Verification Complete"
echo "========================================="