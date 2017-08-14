#!/bin/bash
set -e

mkdir -p /etc/ssl/etcd

mkdir -p /etc/kubernetes/ssl

mv ssl/client* /etc/ssl/etcd/

cp ssl/ca.pem /etc/ssl/etcd/

mv ssl/* /etc/kubernetes/ssl/


chmod 600 /etc/ssl/etcd/*-key.pem
chmod 600 /etc/kubernetes/ssl/*-key.pem

chown root:root /etc/ssl/etcd/*-key.pem
chown root:root /etc/kubernetes/ssl/*-key.pem

source settings.rc

# -------------

function init_config {
    local REQUIRED=( 'ADVERTISE_IP' 'ETCD_ENDPOINTS' 'CONTROLLER_ENDPOINT' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' 'USE_CALICO' 'MAX_PODS')

    if [ -z $MAX_PODS ]; then
        # Number of Pods that can run on this Kubelet. (default 110)
        export MAX_PODS=110
    fi

    if [ "${USE_CALICO}" = "true" ]; then
        export CALICO_OPTS="--volume cni-bin,kind=host,source=/opt/cni/bin \
                            --mount volume=cni-bin,target=/opt/cni/bin"
    else
        export CALICO_OPTS=""
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done
}

function init_templates {
    echo "Installing Templates"
    source inc/docker.sh
    source inc/rkt.sh
    source inc/kubelet-worker.sh
    source inc/kube-proxy.sh
    source inc/flannel.sh
}

init_config
init_templates

chmod +x /opt/bin/host-rkt

echo "Running Daemon reload"
systemctl daemon-reload

if [ $CONTAINER_RUNTIME = "rkt" ]; then
        echo "Load rkt stage1 images"
        systemctl enable load-rkt-stage1
        echo "Enable rkt-api"
        systemctl enable rkt-api
fi

echo "Restarting Flannel"
systemctl enable flanneld; systemctl restart flanneld

echo "Restarting Kubelet"
systemctl enable kubelet; systemctl restart kubelet

echo "DONE"