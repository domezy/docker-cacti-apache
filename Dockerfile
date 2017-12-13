#name of container: docker-cacti
#versison of container: 0.6.1
FROM quantumobject/docker-baseimage:16.04
MAINTAINER Angel Rodriguez  "angel@quantumobject.com"

ENV TZ Asia/Bangkok
ENV CACTI_VERSION=1.1.28

# Update the container
#Installation of nesesary package/software for this containers...
 RUN apt-get update && echo $TZ > /etc/timezone && DEBIAN_FRONTEND=noninteractive apt-get install -yq php7.0 build-essential\
                                                            apache2  snmp libapache2-mod-php7.0 libssl-dev \
                                                            rrdtool librrds-perl php7.0-mysql\
                                                            php7.0-xml php7.0-ldap php7.0-mbstring \
                                                            php7.0-gd php7.0-snmp php7.0-gmp php7.0-mcrypt \
                                                            libmysqlclient-dev libsnmp-dev help2man git \
                                                            snmpd python-netsnmp libnet-snmp-perl snmp-mibs-downloader \
                    && cd /opt/ \
                    && wget https://www.cacti.net/downloads/cacti-"$CACTI_VERSION".tar.gz \
                    && ver=$(tar -tf cacti-"$CACTI_VERSION".tar.gz | head -n1 | tr -d /) \
                    && tar -xvf cacti-"$CACTI_VERSION".tar.gz && mv $ver cacti \
                    && rm cacti-"$CACTI_VERSION".tar.gz \
                    && apt-get clean \
                    && rm -rf /tmp/* /var/tmp/*  \
                    && rm -rf /var/lib/apt/lists/*

# Ensure cron is allowed to run
RUN sed -i 's/^\(session\s\+required\s\+pam_loginuid\.so.*$\)/# \1/g' /etc/pam.d/cron

##Get Mibs
RUN /usr/bin/download-mibs
RUN echo 'mibs +ALL' >> /etc/snmp/snmp.conf
## fix prblem with mibs downloader and ubuntu 16.04
RUN rm /usr/share/mibs/ietf/IPSEC-SPD-MIB \
    && rm /usr/share/mibs/ietf/IPATM-IPMC-MIB \
    && rm /usr/share/mibs/iana/IANA-IPPM-METRICS-REGISTRY-MIB \
    && rm /usr/share/mibs/ietf/SNMPv2-PDU

##startup scripts
#Pre-config scrip that maybe need to be run one time only when the container run the first time .. using a flag to don't
#run it again ... use for conf for service ... when run the first time ...
RUN mkdir -p /etc/my_init.d
COPY startup.sh /etc/my_init.d/startup.sh
RUN chmod +x /etc/my_init.d/startup.sh

##Adding Deamons to containers
# to add apache2 deamon to runit
RUN mkdir -p /etc/service/apache2  /var/log/apache2 ; sync
COPY apache2.sh /etc/service/apache2/run
RUN chmod +x /etc/service/apache2/run  \
    && cp /var/log/cron/config /var/log/apache2/ \
    && chown -R www-data /var/log/apache2

# to add mysqld deamon to runit
#RUN mkdir -p /etc/service/mysqld /var/log/mysqld ; sync
#COPY mysqld.sh /etc/service/mysqld/run
#RUN chmod +x /etc/service/mysqld/run  \
#    && cp /var/log/cron/config /var/log/mysqld/ \
#    && chown -R mysql /var/log/mysqld

# to add snmpd deamon to runit
RUN mkdir -p /etc/service/snmpd /var/log/snmpd ; sync
COPY snmpd.sh /etc/service/snmpd/run
RUN chmod +x /etc/service/snmpd/run  \
   && cp /var/log/cron/config /var/log/snmpd/ \
   && chown -R snmp /var/log/snmpd

#add files and script that need to be use for this container
#include conf file relate to service/daemon
#additionsl tools to be use internally
COPY snmpd.conf /etc/snmp/snmpd.conf
COPY debian.conf /opt/cacti/include/config.php
COPY spine.conf /usr/local/spine/etc/spine.conf

#pre-config scritp for different service that need to be run when container image is create
#maybe include additional software that need to be installed ... with some service running ... like example mysqld
COPY pre-conf.sh /sbin/pre-conf
RUN chmod +x /sbin/pre-conf ; sync \
    && /bin/bash -c /sbin/pre-conf \
    && rm /sbin/pre-conf

##scritp that can be running from the outside using docker-bash tool ...
## for example to create backup for database with convitation of VOLUME   dockers-bash container_ID backup_mysql
COPY backup.sh /sbin/backup
COPY restore.sh /sbin/restore
RUN chmod +x /sbin/backup /sbin/restore
VOLUME /var/backups


# to allow access from outside of the container  to the container service
# at that ports need to allow access from firewall if need to access it outside of the server.
EXPOSE 80

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
