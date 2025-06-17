#!/bin/bash
# deploy-baseline.sh - TAS Baseline Infrastructure Deployment
# 🎯 Creates standardized TAS infrastructure ready for performance testing

set -euo pipefail

# Configuration
BASELINE_NAMESPACE="trusted-artifact-signer"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TAS Baseline Infrastructure Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check OpenShift connection
if oc whoami &> /dev/null; then
    echo -e "${GREEN}Connected to OpenShift as: $(oc whoami)${NC}"
else
    echo -e "${RED}Not connected to OpenShift${NC}"
    echo -e "${YELLOW}   Run: oc login <your-cluster-url>${NC}"
    exit 1
fi

# Check/install Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Installing Ansible...${NC}"
    pip3 install ansible
fi

# Install Kubernetes collection
echo -e "${YELLOW}Installing Ansible Kubernetes collection...${NC}"
ansible-galaxy collection install kubernetes.core --force-with-deps

# Run deployment
echo ""
echo -e "${BLUE}Starting baseline infrastructure deployment...${NC}"
ansible-playbook -i inventory.yml setup-baseline.yml \
    -e baseline_namespace="$BASELINE_NAMESPACE" \
    -v

# Final status
echo ""
echo -e "${GREEN}Baseline infrastructure deployment completed!${NC}"
echo ""