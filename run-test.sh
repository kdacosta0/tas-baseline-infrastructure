#!/bin/bash

# This script serves as a runner and manager for K6 performance tests on OpenShift.
# It automatically handles dependencies, starts the test, and ensures that
# all cluster resources are cleaned up after the test completes or is interrupted.

set -euo pipefail

# --- Configuration ---
K6_TEST_NAMESPACE="k6-tests"
BASELINE_NAMESPACE="tas-monitoring"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="${SCRIPT_DIR}/ansible_venv"
RUN_PLAYBOOK="${SCRIPT_DIR}/run-k6-job.yml"
STOP_PLAYBOOK="${SCRIPT_DIR}/stop-k6-job.yml"

K6_JOB_NAME_VAR="default_k6_job"
for arg in "$@"; do
    if [[ $arg == k6_job_name=* ]]; then
        K6_JOB_NAME_VAR="${arg#*=}"
        break
    fi
done

JOB_NAME="${K6_JOB_NAME_VAR}-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Cleanup Function ---
# This function is ALWAYS called when the script exits, whether successfully or via interruption.
cleanup() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}EXITING: Running cleanup playbook...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    "${VENV_DIR}/bin/ansible-playbook" -i inventory.yml "$STOP_PLAYBOOK" \
        -e k6_test_namespace="$K6_TEST_NAMESPACE" \
        -e baseline_namespace="$BASELINE_NAMESPACE" \
        -e k6_job_name_to_cleanup="$K6_JOB_NAME_VAR"

    echo -e "${GREEN}Cleanup complete.${NC}"
}

trap cleanup EXIT

echo ""
echo -e "${BLUE}Starting K6 test Job '${JOB_NAME}'...${NC}"
"${VENV_DIR}/bin/ansible-playbook" -i inventory.yml "$RUN_PLAYBOOK" \
    -e k6_test_namespace="$K6_TEST_NAMESPACE" \
    -e baseline_namespace="$BASELINE_NAMESPACE" \
    "$@"

echo ""
echo -e "${BLUE}Job '${JOB_NAME}' created. Waiting for Pod to appear...${NC}"

POD_NAME=""
for i in {1..30}; do
    POD_NAME=$(oc get pods -n ${K6_TEST_NAMESPACE} -l job-name=${JOB_NAME} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$POD_NAME" ]; then
        echo -e "${GREEN}Found Pod: ${POD_NAME}${NC}"
        oc wait --for=condition=Ready pod $POD_NAME -n ${K6_TEST_NAMESPACE} --timeout=120s
        break
    fi
    echo "Waiting for Pod to be created... (${i}/30)"
    sleep 2
done

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}ERROR: Timed out waiting for Pod for Job '${JOB_NAME}'.${NC}"
    exit 1
fi

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}Following logs from Pod '${POD_NAME}'...${NC}"
echo -e "${BLUE}(Press Ctrl+C to stop and trigger cleanup)${NC}"
echo -e "${BLUE}======================================================================${NC}"

oc logs -f -n ${K6_TEST_NAMESPACE} ${POD_NAME} -c k6

echo ""
echo -e "${GREEN}Log streaming finished.${NC}"