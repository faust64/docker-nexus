# Build Nexus-Repository-APT Plugin

FROM maven:3-jdk-8-alpine AS build
ENV NEXUS_VERSION=3.16.2 \
    NEXUS_BUILD=01
COPY config/nexus-repository-apt /nexus-repository-apt/
RUN cd /nexus-repository-apt/ \
    && mvn

#    && sed -i "s|3.13.0-01|${NEXUS_VERSION}-${NEXUS_BUILD}|" pom.xml

FROM sonatype/nexus3:3.16.2

# Nexus Repository Manager image for OpenShift Origin

ENV APT_VERSION=1.0.7 \
    NEXUS_BUILD=01 \
    NEXUS_VERSION=3.16.2 \
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
RUN if test "$DO_UPGRADE"; then \
	yum -y upgrade; \
    fi \
    && yum install -y zip unzip \
    && yum install -y which \
    && curl -s get.sdkman.io | bash \
    && source "$HOME/.sdkman/bin/sdkman-init.sh" \
    && mkdir -p /resources /root/.groovy \
    && yes | /bin/bash -l -c "sdk install groovy 2.4.15" \
    && mkdir -p ${SONATYPE_DIR}/nexus/system/net/staticsnow/nexus-repository-apt/${APT_VERSION}/ \
    && sed -i "s@nexus-repository-maven</feature>@nexus-repository-maven</feature>\n        <feature prerequisite=\"false\" dependency=\"false\" version=\"${APT_VERSION}\">nexus-repository-apt</feature>@g" ${SONATYPE_DIR}/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}-${NEXUS_BUILD}/nexus-core-feature-${NEXUS_VERSION}-${NEXUS_BUILD}-features.xml \
    && sed -i "s@<feature name=\"nexus-repository-maven\"@<feature name=\"nexus-repository-apt\" description=\"net.staticsnow:nexus-repository-apt\" version=\"${APT_VERSION}\">\n        <details>net.staticsnow:nexus-repository-apt</details>\n        <bundle>mvn:net.staticsnow/nexus-repository-apt/${APT_VERSION}</bundle>\n        <bundle>mvn:org.apache.commons/commons-compress/1.18</bundle>\n        <bundle>mvn:org.tukaani/xz/1.8</bundle>\n    </feature>\n    <feature name=\"nexus-repository-maven\"@g" ${SONATYPE_DIR}/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}-${NEXUS_BUILD}/nexus-core-feature-${NEXUS_VERSION}-${NEXUS_BUILD}-features.xml

COPY config/*.sh /usr/local/bin/
COPY config/groovy /resources/conf/
COPY config/groovy/grapeConfig.xml /root/.groovy/
COPY --from=build /nexus-repository-apt/target/nexus-repository-apt-${APT_VERSION}.jar ${SONATYPE_DIR}/nexus/system/net/staticsnow/nexus-repository-apt/${APT_VERSION}/

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
ENTRYPOINT ["/usr/local/bin/nexus.sh"]
CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
