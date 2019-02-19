FROM tomcat:8-jre8
MAINTAINER Alexandros Sigaras <als2076@med.cornell.edu>, Fedde Schaeffer <fedde@thehyve.nl>
LABEL Description="cBioPortal for Cancer Genomics"
ENV PORTAL_HOME="/cbioportal"
#======== Install Prerequisites ===============#
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        libmysql-java \
        maven \
        openjdk-8-jdk \
        patch \
        python3 \
        python3-jinja2 \
        python3-mysqldb \
        python3-requests \
    && ln -s /usr/share/java/mysql-connector-java.jar "$CATALINA_HOME"/lib/ \
    && rm -rf $CATALINA_HOME/webapps/examples \
    && rm -rf /var/lib/apt/lists/*
#======== Configure cBioPortal ===========================#
RUN git clone https://github.com/luposung/cbioportal.git $PORTAL_HOME
WORKDIR $PORTAL_HOME
# add buildtime configuration
COPY ./log4j.properties src/main/resources/log4j.properties
#======== Build cBioPortal on Startup ===============#
CMD mvn -DskipTests clean install \
     && cp $PORTAL_HOME/portal/target/cbioportal*.war $CATALINA_HOME/webapps/cbioportal.war \
     # add importer scripts to PATH for easy running in containers
     && find $PWD/core/src/main/scripts/ -type f -executable \! -name '*.pl'  -print0 | xargs -0 -- ln -st /usr/local/bin \
     && sh $CATALINA_HOME/bin/catalina.sh run
# add runtime plumbing to Tomcat config:
# - make cBioPortal honour db config in portal.properties
RUN echo 'CATALINA_OPTS="-Dauthenticate=false $CATALINA_OPTS -Ddbconnector=dbcp"' >>$CATALINA_HOME/bin/setenv.sh
# - tweak server-wide config file
COPY ./catalina_server.xml.patch /root/
RUN patch $CATALINA_HOME/conf/server.xml </root/catalina_server.xml.patch