# TAS Baseline Infrastructure Makefile

.PHONY: help deploy cleanup cleanup-apps check logs status

help:
	@echo "TAS Baseline Infrastructure"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy       - Deploy TAS baseline infrastructure"
	@echo "  cleanup      - Remove ALL TAS resources and operators"
	@echo "  cleanup-apps - Remove only TAS applications (keep operators)"
	@echo "  check        - Verify prerequisites"
	@echo "  status       - Show deployment status"
	@echo "  logs         - Show recent logs"
	@echo ""

# Prerequisites check
check:
	@echo "Checking prerequisites..."
	@command -v ansible-playbook >/dev/null 2>&1 || (echo "ansible-playbook not found" && exit 1)
	@command -v oc >/dev/null 2>&1 || (echo "oc not found" && exit 1)
	@oc cluster-info >/dev/null 2>&1 || (echo "Cannot connect to cluster" && exit 1)
	@echo "Prerequisites OK"

# Deploy TAS baseline infrastructure
deploy: check
	@echo "Deploying TAS baseline infrastructure..."
	chmod +x deploy-baseline.sh
	./deploy-baseline.sh

# Cleanup - remove all resources including operators
cleanup:
	@echo "Cleaning up TAS resources and operators..."
	@echo " Removing application namespaces..."
	oc delete namespace tas-monitoring --ignore-not-found=true
	oc delete namespace trusted-artifact-signer --ignore-not-found=true
	@echo " Removing RHTAS operator..."
	oc delete subscription rhtas-operator -n openshift-operators --ignore-not-found=true
	oc delete csv -n openshift-operators -l operators.coreos.com/rhtas-operator.openshift-operators --ignore-not-found=true
	@echo " Removing Grafana operator..."
	oc delete subscription grafana-operator -n openshift-operators --ignore-not-found=true
	oc delete csv -n openshift-operators -l operators.coreos.com/grafana-operator.openshift-operators --ignore-not-found=true
	@echo " Cleaning up CRDs..."
	oc delete crd --ignore-not-found=true \
		grafanas.grafana.integreatly.org \
		grafanadashboards.grafana.integreatly.org \
		grafanadatasources.grafana.integreatly.org \
		securesigns.rhtas.redhat.com \
		ctlogs.rhtas.redhat.com \
		fulcios.rhtas.redhat.com \
		rekors.rhtas.redhat.com \
		timestampauthorities.rhtas.redhat.com \
		trillians.rhtas.redhat.com \
		tufroots.rhtas.redhat.com
	@echo "Complete cleanup finished"

# Cleanup apps only (keep operators)
cleanup-apps:
	@echo "Cleaning up TAS applications only..."
	oc delete namespace tas-monitoring --ignore-not-found=true
	@echo "Apps cleanup complete (operators preserved)"

# Show deployment status
status:
	@echo "TAS Deployment Status:"
	@echo ""
	@echo "Operators:"
	@oc get csv -n openshift-operators | grep -E "(rhtas|grafana)" || echo "  No operators found"
	@echo ""
	@echo "Namespaces:"
	@oc get ns tas-monitoring || echo "  No TAS namespaces found"
	@echo ""
	@echo "Pods:"
	@oc get pods -n tas-monitoring 2>/dev/null || echo "  No pods in tas-monitoring"