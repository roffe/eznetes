#!/bin/bash
set -e

mkdir -p /etc/ssl/etcd
mv ssl/etcd/* /etc/ssl/etcd/
cp ssl/ca.pem /etc/ssl/etcd/
chmod 600 /etc/ssl/etcd/*-key.pem
chown root:root /etc/ssl/etcd/*-key.pemm

source settings.rc

# -------------

function etcd_initial_cluster_list() {
	local arr=$(echo -n ${ETCD_ENDPOINTS} | tr "," "\n")
	local NO=00
	RES=$(for ETCD in $arr; do
		NO=$((NO + 1))
		echo -n "${CLUSTER_NAME}-etcd$(printf %02d ${NO})=https:$(echo ${ETCD} | cut -d':' -f2):${ETCD_PEER_PORT},"
	done)
	echo ${RES} | sed 's/,$//'
}

function init_templates() {
#	source inc/docker.sh
	source inc/etcd.sh
#	source inc/rkt.sh
#	source inc/kubelet-etcd.sh
#	source inc/kube-proxy.sh
}

init_templates

# chmod +x /opt/bin/host-rkt

echo "Running Daemon reload"
systemctl daemon-reload

docker run -d --restart=always --net=host -v /data/etcd:/data/etcd -v /etc/etcd/etcd.yaml:/etc/etcd/etcd.yaml -v /etc/ssl/etcd:/etc/ssl/etcd  --name=etcd quay.io/coreos/etcd:v3.2 etcd --config-file=/etc/etcd/etcd.yaml

echo "**You must SSH to the node(s) and change initial-cluster-state: 'new' to initial-cluster-state: 'existing' in /etc/etcd/etcd.yaml once initial cluster state is reached for restarts of ETCD to work properly**"
echo "DONE"
