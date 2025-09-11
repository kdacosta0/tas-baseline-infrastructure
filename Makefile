# TAS Baseline Infrastructure Makefile

SIGN_JOB_NAME   := signing
VERIFY_JOB_NAME := verifying
SIGN_SCRIPT     := tas-perf-sign-template.js
VERIFY_SCRIPT   := tas-perf-verify-template.js


.PHONY: help deploy cleanup cleanup-apps check logs status sign-smoke sign-load sign-stress verify-smoke verify-load

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

# Deploy TAS infrastructure
deploy: deploy-baseline

deploy-baseline:
	@echo "Deploying TAS baseline infrastructure..."
	@chmod +x deploy.sh
	@./deploy.sh baseline

deploy-optimized:
	@echo "Deploying TAS optimized infrastructure..."
	@chmod +x deploy.sh
	@./deploy.sh optimized

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
	oc delete namespace k6-tests --ignore-not-found=true --timeout=3m
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
	@$(MAKE) clean-labels

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

clean-labels:
	@echo "INFO: To remove performance labels from worker nodes, run the following commands manually:"
	@for node in $$(oc get nodes -l performance-zone=database -o name); do \
		echo "  oc label $$node performance-zone-"; \
	done
	@for node in $$(oc get nodes -l performance-zone=application -o name); do \
		echo "  oc label $$node performance-zone-"; \
	done

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

sign-smoke:
	@./run-test.sh \
		-e "k6_args='--vus 1 --iterations 1'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)"

sign-fill:
	@./run-test.sh \
		-e "k6_args='--iterations 10000 --vus 50'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)"

sign-load:
	@./run-test.sh \
		-e "k6_args='--stage 30s:20 --stage 5m:20 --stage 30s:0'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)"

sign-stress:
	@./run-test.sh \
		-e "k6_args='--stage 5m:300'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)"

sign-optimal-range:
	@echo "INFO: Running a focused test on the optimal 100 VU range..."
	@./run-test.sh \
		-e "k6_args='--stage 30s:100 --stage 5m:100 --stage 30s:0'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)"

generate-verify-data:
	@echo "INFO: Running sign-smoke in data generation mode..."
	@OUTPUT=$$(./run-test.sh \
		-e "k6_args='--vus 1 --iterations 1'" \
		-e "k6_job_name=$(SIGN_JOB_NAME)" \
		-e "k6_script_to_run=$(SIGN_SCRIPT)" \
		-e "generate_data_mode=true" \
	); \
	echo "Full log output:"; \
	echo "$$OUTPUT"; \
	REKOR_UUID=$$(echo "$$OUTPUT" | grep 'REKOR_ENTRY_UUID' | sed -E 's/.*REKOR_ENTRY_UUID:([0-9a-f]+).*/\1/'); \
	if [ -n "$$REKOR_UUID" ]; then \
		echo "export UUID=$$REKOR_UUID\nmake verify-smoke"; \
	else \
		echo "ERROR: Could not extract UUID"; \
	fi

verify-smoke:
	@echo "INFO: Running verify-smoke test..."
	@./run-test.sh \
		-e "k6_args='--vus 1 --iterations 1'" \
		-e "k6_job_name=$(VERIFY_JOB_NAME)" \
		-e "k6_script_to_run=$(VERIFY_SCRIPT)" \
		-e "rekor_uuids=$(UUID)"

verify-load:
	@echo "INFO: Running verify-load test..."
	@./run-test.sh \
		-e "k6_args='--stage 30s:80 --stage 5m:80 --stage 30s:0'" \
		-e "k6_job_name=$(VERIFY_JOB_NAME)" \
		-e "k6_script_to_run=$(VERIFY_SCRIPT)" \
		-e "rekor_uuids=$(UUID)"

verify-stress:
	@echo "INFO: Running verify-stress test..."
	@./run-test.sh \
		-e "k6_args='--stage 5m:300'" \
		-e "k6_job_name=$(VERIFY_JOB_NAME)" \
		-e "k6_script_to_run=$(VERIFY_SCRIPT)" \
		-e "rekor_uuids=$(UUID)"

verify-optimal-range:
	@echo "INFO: Running a focused test on the optimal VU range..."
	@./run-test.sh \
		-e "k6_args='--stage 30s:100 --stage 5m:100 --stage 30s:0'" \
		-e "k6_job_name=$(VERIFY_JOB_NAME)" \
		-e "k6_script_to_run=$(VERIFY_SCRIPT)" \
		-e "rekor_uuids=$(UUID)"


