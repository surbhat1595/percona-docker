FROM centos:7

LABEL org.opencontainers.image.authors="info@percona.com"

RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
		-c "Default Application User" mysql

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7; \
    \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    yum install -y /tmp/percona-release.rpm; \
    \
    curl -Lf -o /tmp/nss.rpm http://mirror.centos.org/centos/7/updates/x86_64/Packages/nss-3.67.0-4.el7_9.x86_64.rpm; \
    rpmkeys --checksig /tmp/nss.rpm; \
    yum install -y /tmp/nss.rpm; \
    \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    \
    percona-release disable all; \
    percona-release enable original release

# install exact version of PS for repeatability
ENV PERCONA_VERSION 5.6.51-rel91.0.1.el7

RUN set -ex; \
    yum install -y \
        Percona-Server-server-56-${PERCONA_VERSION} \
        Percona-Server-tokudb-56-${PERCONA_VERSION} \
        jemalloc \
        which \
        policycoreutils; \
    \
    yum clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql

# purge and re-create /var/lib/mysql with appropriate ownership
RUN /usr/bin/install -m 0775 -o mysql -g root -d /etc/my.cnf.d /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d \
# comment out a few problematic configuration values
	&& find /etc/my.cnf /etc/my.cnf.d -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user|sql_mode)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user|sql_mode)/#&/' \
# allow enable TokuDB without root
	&& sed -i '/Make sure only root/,/fi/d' /usr/bin/ps_tokudb_admin \
	&& echo "thp-setting=never" >> /etc/my.cnf \
# don't reverse lookup hostnames, they are usually another container
	&& echo '!includedir /etc/my.cnf.d' >> /etc/my.cnf \
	&& printf '[mysqld]\nskip-host-cache\nskip-name-resolve\n' > /etc/my.cnf.d/docker.cnf \
# TokuDB modifications
	&& /usr/bin/install -m 0664 -o mysql -g root /dev/null /etc/sysconfig/mysql \
	&& echo "LD_PRELOAD=/usr/lib64/libjemalloc.so.1" >> /etc/sysconfig/mysql \
	&& echo "THP_SETTING=never" >> /etc/sysconfig/mysql \
# keep backward compatibility with debian images
	&& ln -s /etc/my.cnf.d /etc/mysql \
# allow to change config files
	&& chown -R mysql:root /etc/my.cnf /etc/my.cnf.d \
	&& chmod -R ug+rwX /etc/my.cnf /etc/my.cnf.d

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

COPY ps-entry.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

USER mysql
EXPOSE 3306
CMD ["mysqld"]
