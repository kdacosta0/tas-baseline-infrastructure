#!/bin/bash

set -euo pipefail

# Configuration
BASELINE_NAMESPACE="tas-monitoring"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="${SCRIPT_DIR}/ansible_venv"

DEPLOY_TYPE=${1:-baseline}
ANSIBLE_EXTRA_VARS=""

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

# Check OpenShift connection
if oc whoami &> /dev/null; then
    echo -e "${GREEN}Connected to OpenShift as: $(oc whoami)${NC}"
else
    echo -e "${RED}Not connected to OpenShift${NC}"
    echo -e "${YELLOW}   Run: oc login <your-cluster-url>${NC}"
    exit 1
fi

# Check for virtual environment and install dependencies if needed
if [ ! -f "${VENV_DIR}/bin/ansible-playbook" ]; then
    echo -e "${YELLOW}Setting up Python virtual environment and installing Ansible...${NC}"
    python3 -m venv "${VENV_DIR}"
    
    # Install Python dependencies into the venv
    echo -e "${YELLOW}Installing Python dependencies from requirements.txt...${NC}"
    "${VENV_DIR}/bin/pip" install -r requirements.txt
    
    # Install Ansible Kubernetes collection into the venv
    echo -e "${YELLOW}Installing Kubernetes collection...${NC}"
    "${VENV_DIR}/bin/ansible-galaxy" collection install kubernetes.core
else
    echo -e "${GREEN}Ansible environment is already set up.${NC}"
fi

if [ "$DEPLOY_TYPE" == "optimized" ]; then
    echo "Deployment type: OPTIMIZED"
    ANSIBLE_EXTRA_VARS="-e template_to_deploy=securesign-cr-optimized.yml.j2"
else
    echo "Deployment type: BASELINE"
fi

# Run deployment
echo ""
echo -e "${BLUE}Starting ${DEPLOY_TYPE} infrastructure deployment...${NC}"
"${VENV_DIR}/bin/ansible-playbook" -i inventory.yml setup-baseline.yml \
    -e baseline_namespace="$BASELINE_NAMESPACE" \
    $ANSIBLE_EXTRA_VARS
    
# Final status
echo ""
echo -e "${GREEN}${DEPLOY_TYPE} infrastructure deployment completed!${NC}"
echo ""