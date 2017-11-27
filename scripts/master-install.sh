#!/bin/bash
set -e

mkdir -p /etc/ssl/etcd
mkdir -p /etc/kubernetes/ssl

cp bootstraptoken.csv /etc/kubernetes/ssl/

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
	local REQUIRED=('ADVERTISE_IP' 'POD_NETWORK' 'ETCD_ENDPOINTS' 'SERVICE_IP_RANGE' 'K8S_SERVICE_IP' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' 'USE_WEAVE' 'MAX_PODS')

	if [ -z $MAX_PODS ]; then
		# Number of Pods that can run on this Kubelet. (default 110)
		export MAX_PODS=110
	fi

	if [ "${USE_WEAVE}" = "true" ]; then
		export CNI_OPTS="--volume=opt-cni,kind=host,source=/opt/cni,readOnly=true \
                         --mount volume=opt-cni,target=/opt/weave-net"
	else
		export CNI_OPTS=""
	fi

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
	source inc/kubelet-master.sh
	source inc/kube-proxy.sh
	if [ "${USE_WEAVE}" = "false" ]; then
		source inc/flannel.sh
	fi
	source inc/kube-apiserver.sh
	source inc/kube-controller.sh
	source inc/kube-scheduler.sh
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

if [ "${USE_WEAVE}" = "false" ]; then
	echo "Restarting Flannel"
	systemctl enable flanneld
	systemctl restart flanneld
else
	echo "Stopping Flannel"
	systemctl disable flanneld
	systemctl stop flanneld
	rm -rf /etc/systemd/system/docker.service.d/40-flannel.conf
fi

echo "Restarting Kubelet"
systemctl enable kubelet
systemctl restart kubelet

echo "DONE"
