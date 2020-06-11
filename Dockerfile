FROM sonatype/nexus3:3.24.0

# Nexus Repository Manager image for OpenShift Origin

ENV DI_REPO=https://github.com/Yelp/dumb-init/releases/download \
    DI_VERSION=1.2.2 \
    NEXUS_VERSION=3.24.0 \
    PATH=/root/.sdkman/candidates/groovy/2.4.17/bin:${PATH}

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

#COPY config/groovy /resources/conf/
#COPY config/groovy/grapeConfig.xml /root/.groovy/
#    && yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
#    && yum -y install jq \
#    && curl -s get.sdkman.io | bash \
#    && source "$HOME/.sdkman/bin/sdkman-init.sh" \
#    && mkdir -p /resources /root/.groovy \
#    && yes | /bin/bash -l -c "source $HOME/.sdkman/bin/sdkman-init.sh && sdk install groovy 2.4.17" \

#RUN grape install org.jboss.spec.javax.ws.rs jboss-jaxrs-api_2.0_spec 1.0.1.Final \
#    && grape install org.jboss.spec.javax.servlet jboss-servlet-api_3.1_spec 1.0.2.Final \
#    && grape install org.jboss.spec.javax.annotation jboss-annotations-api_1.2_spec 1.0.2.Final \
#    && grape install javax.activation activation 1.1 \
#    && grape install net.jcip jcip-annotations 1.0 \
#    && grape install org.jboss.logging jboss-logging-annotations 2.2.0.Final \
#    && grape install org.jboss.logging jboss-logging-processor 2.2.0.Final \
#    && grape install com.sun.xml.bind jaxb-impl 2.3.2 \
#    && grape install org.apache.james apache-mime4j 0.6.1 \
#    && grape install org.sonatype.nexus nexus-rest-client 3.17.0-01 \
#    && grape install org.sonatype.nexus nexus-rest-jackson2 3.17.0-01 \
#    && grape install org.sonatype.nexus nexus-script 3.17.0-01 \
#    && grape install com.fasterxml.jackson.core jackson-core 2.9.2 \
#    && grape install com.fasterxml.jackson.core jackson-databind 2.9.2 \
#    && grape install com.fasterxml.jackson.core jackson-annotations 2.9.2 \
#    && grape install com.fasterxml.jackson.jaxrs jackson-jaxrs-json-provider 2.9.2 \
#    && grape install javax.activation activation 1.1 \
#    && grape install net.jcip jcip-annotations 1.0 \
#    && grape install org.jboss.logging jboss-logging-annotations 2.2.0.Final \
#    && grape install org.jboss.logging jboss-logging-processor 2.2.0.Final \
#    && grape install com.sun.xml.bind jaxb-impl 2.3.2 \
#    && grape install com.sun.mail javax.mail 1.6.1 \
#    && chmod 755 /root \
#    && find /root/.groovy -type d -exec chmod 0775 {} \; \
#    && find /root/.groovy -type f -exec chmod 0664 {} \; \
#    && chown -R nexus ${SONATYPE_DIR}/nexus/etc /root/.groovy

USER nexus
ENTRYPOINT ["/bin/dumb-init","--","/usr/local/bin/nexus.sh"]
CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
