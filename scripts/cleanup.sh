#!/bin/bash

##############################################################################
# Cleanup Script - Destroy all resources
##############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║                     CLEANUP WARNING                           ║"
echo "║                                                               ║"
echo "║  This will DESTROY all resources created for the challenge   ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

read -p "Are you sure you want to destroy all resources? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "\n${RED}Starting cleanup...${NC}\n"

cd "$PROJECT_ROOT/infrastructure"

# Terraform destroy
echo "Destroying infrastructure with Terraform..."
terraform destroy -auto-approve

echo -e "\n${GREEN}✅ Infrastructure destroyed${NC}"

# Optional: Delete SSH key
read -p "Delete SSH key pair from AWS? (yes/no): " delete_key

if [ "$delete_key" = "yes" ]; then
    KEY_NAME="jenkins-observability-key"
    aws ec2 delete-key-pair --key-name "$KEY_NAME" || true
    echo -e "${GREEN}✅ SSH key pair deleted${NC}"
    
    read -p "Delete local SSH key file? (yes/no): " delete_local
    if [ "$delete_local" = "yes" ]; then
        rm -f "$HOME/.ssh/${KEY_NAME}.pem"
        echo -e "${GREEN}✅ Local SSH key deleted${NC}"
    fi
fi

# Clean up Terraform state
read -p "Remove Terraform state files? (yes/no): " clean_state

if [ "$clean_state" = "yes" ]; then
    rm -rf .terraform terraform.tfstate* tfplan
    echo -e "${GREEN}✅ Terraform state cleaned${NC}"
fi

# Remove deployment info
rm -f "$PROJECT_ROOT/deployment-info.txt"

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║                  Cleanup Completed                            ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

