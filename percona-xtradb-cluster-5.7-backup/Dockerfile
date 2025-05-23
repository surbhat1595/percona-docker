FROM redhat/ubi9-minimal

# Please don't remove old-style LABEL since it's needed for RedHat certification
LABEL name="Percona XtraBackup" \
	release="2.4" \
	vendor="Percona" \
	summary="Percona XtraBackup is an open-source hot backup utility for MySQL - based servers that doesn’t lock your database during the backup" \
	description="Percona XtraBackup works with MySQL, MariaDB, and Percona Server. It supports completely non-blocking backups of InnoDB, XtraDB, and HailDB storage engines. In addition, it can back up the following storage engines by briefly pausing writes at the end of the backup: MyISAM, Merge, and Archive, including partitioned tables, triggers, and database options." \
	maintainer="Percona Development <info@percona.com>"

LABEL org.opencontainers.image.title="Percona XtraDB Cluster"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona XtraDB Cluster is a high availability solution that \
	helps enterprises avoid downtime and outages and meet expected customer experience."
LABEL org.opencontainers.image.license="GPL"

ENV PXB_VERSION=2.4.29-1
ENV PXC_VERSION=5.7.44-31.65.1
ENV OS_VER=el9
ENV FULL_PERCONA_XTRABACKUP_VERSION="$PXB_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRADBCLUSTER_VERSION="$PXC_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PXC_VERSION}
LABEL org.opencontainers.image.version=${PXC_VERSION}

# check repository package signature in secure way
RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F FB5DB77FD5C118B80511ADA8A6310ACC4672475C; \
	gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
	gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
	gpg --batch --export --armor FB5DB77FD5C118B80511ADA8A6310ACC4672475C > ${GNUPGHOME}/RPM-GPG-KEY-aws; \
	rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/RPM-GPG-KEY-aws; \
	microdnf install -y findutils; \
	curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
	rpmkeys --checksig /tmp/percona-release.rpm; \
	curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip;  \
	curl -o /tmp/awscliv2.sig https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig; \
	gpg --verify /tmp/awscliv2.sig /tmp/awscliv2.zip; \
	rpm -i /tmp/percona-release.rpm; \
	rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
	rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
	percona-release enable-only tools release; \
	percona-release enable pxc-57 release

RUN set -ex; \
	curl -Lf -o /tmp/libev.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/libev-4.33-5.el9.x86_64.rpm; \
	curl -Lf -o /tmp/pv.rpm https://yum.oracle.com/repo/OracleLinux/OL9/developer/EPEL/x86_64/getPackage/pv-1.6.20-1.el9.x86_64.rpm; \
	curl -Lf -o /tmp/boost-program-options.rpm https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64/getPackage/boost-program-options-1.75.0-8.el9.x86_64.rpm; \
	rpmkeys --checksig /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm; \
	rpm -i /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm; \
	rm -rf /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm

RUN set -ex; \
	microdnf install -y \
	shadow-utils \
	hostname \
	findutils \
	diffutils \
	openssl \
	numactl-libs \
	jq \
	socat \
	iputils \
	procps-ng \
	util-linux \
	unzip \
	procps-ng \
	qpress \
	tar \
	cracklib-dicts \
	libatomic \
	libaio; \
	microdnf clean all; \
	unzip -q /tmp/awscliv2.zip -d /tmp/; \
	/tmp/aws/install; \
	rm -rf /var/cache/dnf /var/cache/yum /tmp/awscliv2.zip /tmp/awscliv2.sig /tmp/aws

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
	useradd -u 1001 -r -g 1001 -s /sbin/nologin \
	-c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
	curl -Lf -o /tmp/Percona-XtraDB-Cluster-garbd-57.rpm https://repo.percona.com/yum/release/9/RPMS/x86_64/Percona-XtraDB-Cluster-garbd-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/Percona-XtraDB-Cluster-client-57.rpm https://repo.percona.com/yum/release/9/RPMS/x86_64/Percona-XtraDB-Cluster-client-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-xtrabackup-24.rpm http://repo.percona.com/percona/yum/release/9/RPMS/x86_64/percona-xtrabackup-24-${FULL_PERCONA_XTRABACKUP_VERSION}.x86_64.rpm; \
	rpm --checksig /tmp/Percona-XtraDB-Cluster-garbd-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm; \
	rpm -iv /tmp/Percona-XtraDB-Cluster-garbd-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm --nodeps; \
	rm -rf /tmp/Percona-XtraDB-Cluster-garbd-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm; \
	rpm -ql Percona-XtraDB-Cluster-client-57 | egrep -v "mysql$|mysqldump$|mysqlbinlog$" | xargs rm -rf; \
	microdnf clean all; \
	rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtrabackup-24/COPYING /licenses/LICENSE.xtrabackup; \
	cp /usr/share/doc/percona-xtradb-cluster-garbd-3/COPYING /licenses/LICENSE.garbd

RUN install -d -o 1001 -g 0 -m 0775 /backup; \
	mkdir /usr/lib/pxc

COPY lib/pxc /usr/lib/pxc
COPY recovery-*.sh backup.sh get-pxc-state /usr/bin/

VOLUME ["/backup"]
USER 1001

CMD ["sleep","infinity"]
