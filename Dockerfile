FROM sonatype/nexus3:3.24.0

# Nexus Repository Manager image for OpenShift Origin

ENV DI_REPO=https://github.com/Yelp/dumb-init/releases/download \
    DI_VERSION=1.2.2 \
    NEXUS_BUILD=01 \
    NEXUS_VERSION=3.24.0 \
    PATH=/root/.sdkman/candidates/groovy/2.4.15/bin:${PATH}

LABEL io.k8s.description="Nexus Repository Manager for OpenShift." \
      io.k8s.display-name="Nexus3 ${NEXUS_VERSION}-${NEXUS_BUILD}" \
      io.openshift.expose-services="8081:http" \
      io.openshift.tags="nexus,repository,nexus3" \
      io.openshift.non-scalable="true" \
      help="For more information visit https://github.com/faust64/docker-nexus" \
      maintainer="Samuel MARTIN MORO <faust64@gmail.com>" \
      version="${NEXUS_VERSION}-${NEXUS_BUILD}"

USER root
RUN set -x && if test "$DO_UPGRADE"; then \
	dnf -y upgrade; \
    fi \
    && dnf install -y zip unzip which \
    && curl -s get.sdkman.io | bash \
    && source "$HOME/.sdkman/bin/sdkman-init.sh" \
    && curl -fsL ${DI_REPO}/v${DI_VERSION}/dumb-init_${DI_VERSION}_amd64 \
	-o /bin/dumb-init \
    && chmod +x /bin/dumb-init \
    && mkdir -p /resources /root/.groovy \
    && yes | /bin/bash -l -c "source $HOME/.sdkman/bin/sdkman-init.sh && sdk install groovy 2.4.15" \
    && rm -rf /var/cache/yum /usr/share/doc /usr/share/man \
    && unset HTTP_PROXY HTTPS_PROXY NO_PROXY DO_UPGRADE http_proxy https_proxy

COPY config/*.sh /usr/local/bin/
COPY config/groovy /resources/conf/
COPY config/groovy/grapeConfig.xml /root/.groovy/

RUN grape install org.sonatype.nexus nexus-rest-client 3.6.0-02 \
    && grape install org.sonatype.nexus nexus-rest-jackson2 3.6.0-02 \
    && grape install org.sonatype.nexus nexus-script 3.6.0-02 \
    && grape install org.jboss.spec.javax.servlet jboss-servlet-api_3.1_spec 1.0.0.Final \
    && grape install com.fasterxml.jackson.core jackson-core 2.8.6 \
    && grape install com.fasterxml.jackson.core jackson-databind 2.8.6 \
    && grape install com.fasterxml.jackson.core jackson-annotations 2.8.6 \
    && grape install com.fasterxml.jackson.jaxrs jackson-jaxrs-json-provider 2.8.6 \
    && grape install org.jboss.spec.javax.ws.rs jboss-jaxrs-api_2.0_spec 1.0.1.Beta1 \
    && grape install org.jboss.spec.javax.annotation jboss-annotations-api_1.2_spec 1.0.0.Final \
    && grape install javax.activation activation 1.1.1 \
    && grape install net.jcip jcip-annotations 1.0 \
    && grape install org.jboss.logging jboss-logging-annotations 2.0.1.Final \
    && grape install org.jboss.logging jboss-logging-processor 2.0.1.Final \
    && grape install com.sun.xml.bind jaxb-impl 2.2.7 \
    && grape install com.sun.mail javax.mail 1.5.6 \
    && grape install org.apache.james apache-mime4j 0.6 \
    && chmod 755 /root \
    && find /root/.groovy -type d -exec chmod 0775 {} \; \
    && find /root/.groovy -type f -exec chmod 0664 {} \; \
    && chown -R nexus ${SONATYPE_DIR}/nexus/etc /root/.groovy

USER nexus
ENTRYPOINT ["/bin/dumb-init","--","/usr/local/bin/nexus.sh"]
CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
