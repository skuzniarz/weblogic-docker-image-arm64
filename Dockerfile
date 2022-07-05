FROM container-registry.oracle.com/middleware/weblogic:14.1.1.0 AS wls-base

FROM oraclelinux:8

ARG JDK_PKG

RUN mkdir /u01 && \
    useradd -b /u01 -d /u01/oracle -m -s /bin/bash oracle

ENV JDK_PKG=${JDK_PKG}
COPY --chown=oracle:oracle $JDK_PKG /u01/
RUN yum install -y tar && tar -x -C /u01 -f /u01/$JDK_PKG && rm /u01/$JDK_PKG

COPY --from=wls-base --chown=oracle:oracle /u01/oracle /u01/oracle

RUN echo "export JAVA_HOME=/u01/$(ls -1 /u01 | grep j)" >> /u01/oracle/.bash_profile
RUN echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /u01/oracle/.bash_profile

USER oracle

ENV ORACLE_HOME=/u01/oracle \
    MW_HOME=/u01/oracle \
    WLS_HOME=/u01/oracle/wlserver \
    WL_HOME=/u01/oracle/wlserver \
    USER_MEM_ARGS="-Djava.security.egd=file:/dev/./urandom" \
    SCRIPT_FILE=/u01/oracle/createAndStartEmptyDomain.sh \
    HEALTH_SCRIPT_FILE=/u01/oracle/get_healthcheck_url.sh \
    PATH=$PATH:${JAVA_HOME}/bin:/u01/oracle/oracle_common/common/bin:/u01/oracle/wlserver/common/bin

ENV DOMAIN_NAME="${DOMAIN_NAME:-base_domain}" \
    ADMIN_LISTEN_PORT="${ADMIN_LISTEN_PORT:-7001}"  \
    ADMIN_NAME="${ADMIN_NAME:-AdminServer}" \
    DEBUG_FLAG=true \
    PRODUCTION_MODE=dev \
    ADMINISTRATION_PORT_ENABLED="${ADMINISTRATION_PORT_ENABLED:-true}" \
    ADMINISTRATION_PORT="${ADMINISTRATION_PORT:-9002}"

COPY --chown=oracle:root container-scripts/createAndStartEmptyDomain.sh container-scripts/create-wls-domain.py container-scripts/get_healthcheck_url.sh /u01/oracle/
RUN chmod +xr $SCRIPT_FILE $HEALTH_SCRIPT_FILE

USER oracle

HEALTHCHECK --start-period=10s --timeout=30s --retries=3 CMD curl -k -s --fail `$HEALTH_SCRIPT_FILE` || exit 1
WORKDIR ${ORACLE_HOME}

CMD [ "/bin/bash", "-l", "-c", "/u01/oracle/createAndStartEmptyDomain.sh" ]
