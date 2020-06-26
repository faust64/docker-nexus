FROM sonatype/nexus3:3.24.0

# Nexus Repository Manager image for OpenShift Origin

ENV DI_REPO=https://github.com/Yelp/dumb-init/releases/download \
    DI_VERSION=1.2.2 \
    NEXUS_VERSION=3.24.0

LABEL io.k8s.description="Nexus Repository Manager for OpenShift." \
      io.k8s.display-name="Nexus3 ${NEXUS_VERSION}" \
      io.openshift.expose-services="8081:http" \
      io.openshift.tags="nexus,repository,nexus3" \
      io.openshift.non-scalable="true" \
      help="For more information visit https://github.com/faust64/docker-nexus" \
      maintainer="Samuel MARTIN MORO <faust64@gmail.com>" \
      version="${NEXUS_VERSION}"

USER root
COPY config/el8.repo /etc/yum.repos.d/
RUN set -x \
    && if test "$DO_UPGRADE"; then \
	dnf -y upgrade; \
    fi \
    && dnf -y install zip unzip which \
    && curl -fsL ${DI_REPO}/v${DI_VERSION}/dumb-init_${DI_VERSION}_amd64 \
	-o /bin/dumb-init \
    && chmod +x /bin/dumb-init \
    && rm -rf /var/cache/yum /usr/share/doc /usr/share/man \
    && unset HTTP_PROXY HTTPS_PROXY NO_PROXY DO_UPGRADE http_proxy https_proxy

COPY config/*.sh /usr/local/bin/

USER nexus
ENTRYPOINT ["/bin/dumb-init","--","/usr/local/bin/nexus.sh"]
CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
