# TAS Baseline Infrastructure Makefile

.PHONY: help deploy cleanup cleanup-apps check logs status

help:
	@echo "TAS Baseline Infrastructure"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy       - Deploy TAS baseline infrastructure"
	@echo "  clean        - Remove ALL TAS resources and operators"
	@echo "  clean-apps   - Remove only TAS applications (keep operators)"
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

# Clean - remove all resources including operators
clean:
	@echo "Cleaning up TAS resources and operators..."

	@echo " Deleting Keycloak resources..."
	oc delete keycloakrealm trusted-artifact-signer -n keycloak-system --ignore-not-found=true --wait=true --timeout=2m
	oc delete keycloakclient trusted-artifact-signer -n keycloak-system --ignore-not-found=true --wait=true --timeout=2m
	oc delete keycloakuser jdoe -n keycloak-system --ignore-not-found=true --wait=true --timeout=2m
	oc delete keycloak keycloak -n keycloak-system --ignore-not-found=true --wait=true --timeout=3m
	
	@echo " Removing application namespaces..."
	oc delete namespace tas-monitoring --ignore-not-found=true --timeout=3m
	oc delete namespace trusted-artifact-signer --ignore-not-found=true --timeout=3m

	@echo " Removing Keycloak operator..."
	oc delete subscription keycloak-operator -n keycloak-system --ignore-not-found=true
	oc delete csv -n keycloak-system -l operators.coreos.com/keycloak-operator.keycloak-system --ignore-not-found=true
	@echo " Removing RHTAS operator..."
	oc delete subscription rhtas-operator -n openshift-operators --ignore-not-found=true
	oc delete csv -n openshift-operators -l operators.coreos.com/rhtas-operator.openshift-operators --ignore-not-found=true
	@echo " Removing Grafana operator..."
	oc delete subscription grafana-operator -n openshift-operators --ignore-not-found=true
	oc delete csv -n openshift-operators -l operators.coreos.com/grafana-operator.openshift-operators --ignore-not-found=true

	@echo " Removing Keycloak namespace..."
	oc delete namespace keycloak-system --ignore-not-found=true --timeout=3m
	
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
		tufs.rhtas.redhat.com \
		keycloaks.keycloak.org \
		keycloakrealms.keycloak.org \
		keycloakclients.keycloak.org \
		keycloakusers.keycloak.org \
		keycloakbackups.keycloak.org
	@echo "Complete cleanup finished"

force-clean:
	@echo "Forcefully removing finalizers from Keycloak resources..."
	oc patch keycloakrealm trusted-artifact-signer -n keycloak-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
	oc patch keycloakclient trusted-artifact-signer -n keycloak-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
	oc patch keycloakuser jdoe -n keycloak-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
	oc patch keycloak keycloak -n keycloak-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
	@echo "Finalizers removed. Now running standard clean..."
	$(MAKE) clean


clean-apps:
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