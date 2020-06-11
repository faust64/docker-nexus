SKIP_SQUASH?=1

-include Makefile.cust

.PHONY: build
build:
	SKIP_SQUASH=$(SKIP_SQUASH) hack/build.sh

.PHONY: test
test:
	SKIP_SQUASH=$(SKIP_SQUASH) TAG_ON_SUCCESS=$(TAG_ON_SUCCESS) TEST_MODE=true hack/build.sh

.PHONY: demo
demo:
	docker run -p8081:8081 \
	     -e NEXUS_JENKINS_DEPLOYER_ACCOUNT=jk-deploy \
	     -e NEXUS_JENKINS_ARTIFACTS_ACCOUNT=jk-artifacts \
	     -e NEXUS_DEPLOYER_SERVICE_PASSWORD=secret \
	     -e NEXUS_ARTIFACTS_SERVICE_PASSWORD=secret \
	     -e NEXUS_ADMIN_PASSWORD=admin4242 \
	     ci/nexus

.PHONY: run
run:
	docker run -p8081:8081 ci/nexus

.PHONY: ocbuild
ocbuild: occheck
	oc process -f openshift/imagestream.yaml | oc apply -f-
	BRANCH=`git rev-parse --abbrev-ref HEAD`; \
	if test "$$GIT_DEPLOYMENT_TOKEN"; then \
	    oc process -f openshift/build-with-secret.yaml \
		-p "GIT_DEPLOYMENT_TOKEN=$$GIT_DEPLOYMENT_TOKEN" \
		-p "NEXUS_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	else \
	    oc process -f openshift/build.yaml \
		-p "NEXUS_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	fi

.PHONY: occheck
occheck:
	oc whoami >/dev/null 2>&1 || exit 42

.PHONY: occlean
occlean: occheck
	oc process -f openshift/run-persistent.yaml | oc delete -f- || true
	oc process -f openshift/secret.yaml | oc delete -f- || true
