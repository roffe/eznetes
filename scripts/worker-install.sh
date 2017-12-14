#!/bin/bash
set -e

mkdir -p /etc/ssl/etcd

mkdir -p /etc/kubernetes/ssl

cp ssl/client* /etc/ssl/etcd/
rm ssl/client*

cp ssl/ca.pem /etc/ssl/etcd/

cp ssl/* /etc/kubernetes/ssl/

chmod 600 /etc/ssl/etcd/*-key.pem
chmod 600 /etc/kubernetes/ssl/*-key.pem

chown root:root /etc/ssl/etcd/*-key.pem
chown root:root /etc/kubernetes/ssl/*-key.pem

source settings.rc

# -------------

function init_config() {
	local REQUIRED=('ADVERTISE_IP' 'ETCD_ENDPOINTS' 'CONTROLLER_ENDPOINT' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' 'MAX_PODS')

	if [ -z $MAX_PODS ]; then
		# Number of Pods that can run on this Kubelet. (default 110)
		export MAX_PODS=110
	fi
	
	export CNI_OPTS=""

	for REQ in "${REQUIRED[@]}"; do
		if [ -z "$(eval echo \$$REQ)" ]; then
			echo "Missing required config value: ${REQ}"
			exit 1
		fi
	done
}

function init_templates() {
	echo "Installing Templates"
	source inc/kernel.sh
	source inc/docker.sh
	source inc/rkt.sh
	source inc/kubelet-worker.sh
#   source inc/kube-proxy.sh
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
else
	echo "Starting & enabling Docker"
	systemctl enable docker
	systemctl start docker
fi

echo "Restarting Kubelet"
systemctl enable kubelet
systemctl restart kubelet

echo "DONE"
