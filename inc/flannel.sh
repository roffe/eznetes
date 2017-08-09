#!/bin/bash
function init_flannel {
    if which etcdctl >/dev/null; then
        echo "Setting Flannel settings in ETCD"
        echo "ETCD Endpoints: ${ETCD_ENDPOINTS}"
        echo "POD Network: ${POD_NETWORK}"
        local F_SETTINGS="{\"Network\":\"${POD_NETWORK}\",\"Backend\":{\"Type\":\"vxlan\"}}"
        ETCDCTL_API=2 etcdctl --ca-file certs/ca/ca.pem --key-file certs/etcd/client/client-key.pem --cert-file certs/etcd/client/client.pem --endpoints "${ETCD_ENDPOINTS}" set coreos.com/network/config "${F_SETTINGS}" > /dev/null
        if [ $? -eq 0 ]; then
            echo "Success setting Flannel settings:"
            echo "${F_SETTINGS}"
        else
            echo "Error setting Flannel settings"
        fi
    else
        echo "etcdctl missing, you need to install it for your current OS"
        echo "https://github.com/coreos/etcd/releases/"
    fi
}