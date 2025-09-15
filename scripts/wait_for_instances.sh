#!/bin/bash

# wait_for_instances.sh - Wait for EC2 instances to be ready for configuration

set -e

# Configuration
MAX_WAIT_TIME=300  # 5 minutes
CHECK_INTERVAL=10  # 10 seconds

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "Waiting for EC2 Instances to be Ready"
echo "========================================="

# Get instance IDs from Terraform or arguments
if [ -z "$1" ]; then
    echo "Getting instance IDs from Terraform state..."
    cd terraform
    INSTANCE_IDS=$(terraform output -json instance_ids 2>/dev/null | jq -r '.[]' | tr '\n' ' ')
    cd ..
else
    INSTANCE_IDS="$@"
fi

if [ -z "$INSTANCE_IDS" ]; then
    echo -e "${RED}No instance IDs found${NC}"
    exit 1
fi

echo "Instance IDs: $INSTANCE_IDS"
echo ""

# Function to wait for instance
wait_for_instance() {
    local instance_id=$1
    local elapsed=0
    
    echo "Waiting for instance $instance_id..."
    
    # Wait for instance to be running
    echo -n "  Checking instance state..."
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        STATE=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ "$STATE" == "running" ]; then
            echo -e " ${GREEN}running${NC}"
            break
        fi
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        echo -n "."
    done
    
    if [ "$STATE" != "running" ]; then
        echo -e " ${RED}timeout (state: $STATE)${NC}"
        return 1
    fi
    
    # Wait for status checks
    echo -n "  Waiting for status checks..."
    elapsed=0
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        STATUS=$(aws ec2 describe-instance-status \
            --instance-ids "$instance_id" \
            --query 'InstanceStatuses[0].InstanceStatus.Status' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ "$STATUS" == "ok" ]; then
            echo -e " ${GREEN}passed${NC}"
            break
        fi
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        echo -n "."
    done
    
    # Wait for SSM agent
    echo -n "  Waiting for SSM agent..."
    elapsed=0
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        SSM_STATUS=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$instance_id" \
            --query 'InstanceInformationList[0].PingStatus' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ "$SSM_STATUS" == "Online" ]; then
            echo -e " ${GREEN}online${NC}"
            break
        fi
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        echo -n "."
    done
    
    if [ "$SSM_STATUS" != "Online" ]; then
        echo -e " ${YELLOW}warning: SSM not ready${NC}"
    fi
    
    # Get instance details
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
    
    echo -e "  ${GREEN}✓${NC} Instance ready"
    echo "    Public IP: $PUBLIC_IP"
    echo "    Private IP: $PRIVATE_IP"
    echo ""
    
    return 0
}

# Wait for all instances
FAILED_INSTANCES=""
for instance_id in $INSTANCE_IDS; do
    if ! wait_for_instance "$instance_id"; then
        FAILED_INSTANCES="$FAILED_INSTANCES $instance_id"
    fi
done

# Summary
echo "========================================="
if [ -z "$FAILED_INSTANCES" ]; then
    echo -e "${GREEN}All instances are ready!${NC}"
    exit 0
else
    echo -e "${RED}Some instances failed to become ready:${NC}"
    echo "$FAILED_INSTANCES"
    exit 1
fi