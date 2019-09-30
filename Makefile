SKIP_SQUASH?=1

.PHONY: build
build:
	SKIP_SQUASH=$(SKIP_SQUASH) hack/build.sh
.PHONY: test
test:
	SKIP_SQUASH=$(SKIP_SQUASH) TAG_ON_SUCCESS=$(TAG_ON_SUCCESS) TEST_MODE=true hack/build.sh

demo:
	docker run -p8081:8081 \
	     -e LDAP_ENABLED=true \
	     -e LDAP_BIND_DN=cn=admin0,ou=users,dc=demo,dc=local \
	     -e LDAP_BIND_PW=secret \
	     -e LDAP_URI=ldap://172.17.0.1:389 \
	     -e LDAP_BASE=dc=demo,dc=local \
	     -e NEXUS_CUSTOM_ADMIN_ROLE=ldapAdmin \
	     -e NEXUS_JENKINS_DEPLOYER_ACCOUNT=jk-deploy \
	     -e NEXUS_JENKINS_ARTIFACTS_ACCOUNT=jk-artifacts \
	     -e NEXUS_DEPLOYER_SERVICE_PASSWORD=secret \
	     -e NEXUS_ARTIFACTS_SERVICE_PASSWORD=secret \
	     -e NEXUS_ADMIN_PASSWORD=admin4242 \
	     ci/nexus

run:
	docker run -p8081:8081 ci/nexus

.PHONY: ocbuild
ocbuild: occheck
	oc process -f openshift/imagestream.yaml -p FRONTNAME=wsweet | oc apply -f-
	BRANCH=`git rev-parse --abbrev-ref HEAD`; \
	if test "$$GIT_DEPLOYMENT_TOKEN"; then \
	    oc process -f openshift/build-with-secret.yaml \
		-p "FRONTNAME=wsweet" \
		-p "GIT_DEPLOYMENT_TOKEN=$$GIT_DEPLOYMENT_TOKEN" \
		-p "NEXUS_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	else \
	    oc process -f openshift/build.yaml \
		-p "FRONTNAME=wsweet" \
		-p "NEXUS_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	fi

.PHONY: occheck
occheck:
	oc whoami >/dev/null 2>&1 || exit 42

.PHONY: occlean
occlean: occheck
	oc process -f openshift/run-persistent.yaml -p FRONTNAME=wsweet | oc delete -f- || true
	oc process -f openshift/secret.yaml -p FRONTNAME=wsweet | oc delete -f- || true
