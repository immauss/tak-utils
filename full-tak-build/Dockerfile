ARG BASE_REGISTRY=registry1.dso.mil
ARG BASE_IMAGE=ironbank/redhat/ubi/ubi8
ARG BASE_TAG=8.10
FROM $BASE_REGISTRY/$BASE_IMAGE:$BASE_TAG

ARG TAKSERVER_DEPENDENCY_FILENAME=takserver-docker-5.3-RELEASE-24
ARG TAKSERVER_DEPENDENCY_ZIPFILE=$TAKSERVER_DEPENDENCY_FILENAME.zip

USER root

RUN dnf upgrade -y && \
    dnf install -y --disableplugin=subscription-manager --nodocs \
           java-17-openjdk freetype fontconfig dejavu-sans-fonts openssl \
           net-tools \
	       unzip \
           vim && \
    dnf clean all && \
    rm -rf /var/cache/dnf

#link openssl to openssl3
#RUN ln -s /usr/bin/openssl3 /usr/bin/openssl

RUN useradd -g 0 -u 1001 tak \
    && usermod -a -G root tak

RUN mkdir /opt/tak
RUN chown tak:0 /opt/tak

COPY $TAKSERVER_DEPENDENCY_ZIPFILE "/opt/tak/"

RUN cd /opt/tak && unzip $TAKSERVER_DEPENDENCY_ZIPFILE
RUN cd /opt/tak && rm $TAKSERVER_DEPENDENCY_ZIPFILE

RUN cp -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME/tak/* /opt/tak
RUN cp -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME/docker/* /opt/tak/
#RUN rm /opt/tak/utils/takcl.jar 
RUN rm -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME

COPY scripts/health_check.sh /opt/tak/health/takserver/health_check.sh

RUN chown -R tak:0 /opt/tak

RUN chmod u=rwx /opt/tak \
    && find /opt/tak/ -type d -exec chmod u=rwx {} \; \
    && find /opt/tak/ -type f -name "*.*" -exec chmod u=rw {} \; \
    && find /opt/tak/ -type f -name "*.sh" -exec chmod u=rx {} \;

ENV JAVA_HOME=/usr/lib/jvm/jre-17-openjdk

#fix fips related issue, takserver needs the non fips providers so simply set them as fips providers so that they are available
RUN echo "fips.provider.1=SUN" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.2=SunRsaSign" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.3=SunEC" >> $JAVA_HOME/conf/security/java.securitysudo
RUN echo "fips.provider.4=SunJSSE" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.5=SunJCE" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.6=SunJGSS" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.7=SunSASL" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.8=XMLDSig" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.9=SunPCSC" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.10=JdkLDAP" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.11=JdkSASL" >> $JAVA_HOME/conf/security/java.security
RUN echo "fips.provider.12=SunPKCS11" >> $JAVA_HOME/conf/security/java.security


USER tak:0

HEALTHCHECK --start-period=120s --interval=30s --timeout=30s --retries=10 CMD /opt/tak/health/takserver/health_check.sh || exit 1

# Default startup executable. Can include elements of 'docker run' command as parameters.
ENTRYPOINT ["/bin/bash", "-c", "/opt/tak/configureInDocker.sh init &>> /opt/tak/logs/takserver.log"]
