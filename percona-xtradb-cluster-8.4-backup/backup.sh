#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/backup.sh

GARBD_OPTS=""

function get_backup_source() {
    CLUSTER_SIZE=$(/opt/percona/peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
        | grep wsrep_cluster_size \
        | sort \
        | tail -1 \
        | cut -d : -f 12)

    if [ -z "${CLUSTER_SIZE}" ]; then
        exit 1
    fi

    FIRST_NODE=$(/opt/percona/peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
        | grep wsrep_ready:ON:wsrep_connected:ON:wsrep_local_state_comment:Synced:wsrep_cluster_status:Primary \
        | sort -r \
        | tail -1 \
        | cut -d : -f 2 \
        | cut -d . -f 1)

    SKIP_FIRST_POD='|'
    if (( ${CLUSTER_SIZE:-0} > 1 )); then
        SKIP_FIRST_POD="$FIRST_NODE"
    fi
    /opt/percona/peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
        | grep wsrep_ready:ON:wsrep_connected:ON:wsrep_local_state_comment:Synced:wsrep_cluster_status:Primary \
        | grep -v $SKIP_FIRST_POD \
        | sort \
        | tail -1 \
        | cut -d : -f 2 \
        | cut -d . -f 1
}

function check_ssl() {
    CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    if [ -f /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt ]; then
        CA=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
    fi
    SSL_DIR=${SSL_DIR:-/etc/mysql/ssl}
    if [ -f ${SSL_DIR}/ca.crt ]; then
        CA=${SSL_DIR}/ca.crt
    fi
    SSL_INTERNAL_DIR=${SSL_INTERNAL_DIR:-/etc/mysql/ssl-internal}
    if [ -f ${SSL_INTERNAL_DIR}/ca.crt ]; then
        CA=${SSL_INTERNAL_DIR}/ca.crt
    fi

    KEY=${SSL_DIR}/tls.key
    CERT=${SSL_DIR}/tls.crt
    if [ -f ${SSL_INTERNAL_DIR}/tls.key -a -f ${SSL_INTERNAL_DIR}/tls.crt ]; then
        KEY=${SSL_INTERNAL_DIR}/tls.key
        CERT=${SSL_INTERNAL_DIR}/tls.crt
    fi

    if [ -f "$CA" -a -f "$KEY" -a -f "$CERT" ]; then
         GARBD_OPTS="socket.ssl_ca=${CA};socket.ssl_cert=${CERT};socket.ssl_key=${KEY};socket.ssl_cipher=;pc.weight=0;${GARBD_OPTS}"
    fi
}

function request_streaming() {
    local LOCAL_IP=$(hostname -i | sed -E 's/.*\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\b.*/\1/')
    local NODE_NAME=$(get_backup_source)

    if [ -z "$NODE_NAME" ]; then
        /opt/percona/peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE
        log 'ERROR' 'Cannot find node for backup'
        log 'ERROR' 'Backup was finished unsuccessful'
        exit 1
    fi

    set +o errexit
    log 'INFO' 'Garbd was started'
    garbd \
        --address "gcomm://$NODE_NAME.$PXC_SERVICE?gmcast.listen_addr=tcp://0.0.0.0:4567" \
        --donor "$NODE_NAME" \
        --group "$PXC_SERVICE" \
        --options "$GARBD_OPTS" \
        --sst "xtrabackup-v2:$LOCAL_IP:4444/xtrabackup_sst//1" \
        --recv-script="/usr/bin/run_backup.sh" 2>&1 | tee /tmp/garbd.log

    if grep 'Will never receive state. Need to abort' /tmp/garbd.log; then
        exit 1
    fi

    if grep 'Donor is no longer in the cluster, interrupting script' /tmp/garbd.log; then
        exit 1
    elif grep 'failed: Invalid argument' /tmp/garbd.log; then
        exit 1
    fi

    if [ -f '/tmp/backup-is-completed' ]; then
        log 'INFO' 'Backup was finished successfully'
        exit 0
    fi

    log 'ERROR' 'Backup was finished unsuccessful'

    exit 1
}

check_ssl
if [ -n "${S3_BUCKET}" ]; then
   clean_backup_s3
elif [ -n "$AZURE_CONTAINER_NAME" ]; then
   clean_backup_azure
fi
request_streaming

exit 0
