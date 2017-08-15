#!/bin/bash
function init_flannel() {
	if which etcdctl >/dev/null; then
		echo "Setting Flannel settings in ETCD"
		echo "ETCD Endpoints: ${ETCD_ENDPOINTS}"
		echo "POD Network: ${POD_NETWORK}"
		local F_SETTINGS="{\"Network\":\"${POD_NETWORK}\",\"Backend\":{\"Type\":\"vxlan\"}}"
		ETCDCTL_API=2 etcdctl --ca-file certs/ca/ca.pem --key-file certs/etcd/client/client-key.pem --cert-file certs/etcd/client/client.pem --endpoints "${ETCD_ENDPOINTS}" set coreos.com/network/config "${F_SETTINGS}" >/dev/null
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

# Start a insecure apiserver locally that we will use to add out first services & addons to kubernetes.
function init_k8s() {
	create_apiserver_cert "127.0.0.1" "localhost"
	echo "Starting local apiserver"
	docker run --rm -d --name k8s-bootstrap \
		-p 8080:8080 \
		-v ${PWD}/certs/ca/ca.pem:/etc/ssl/ca.pem \
		-v ${PWD}/certs/etcd/client/client.pem:/etc/ssl/etcd/client.pem \
		-v ${PWD}/certs/etcd/client/client-key.pem:/etc/ssl/etcd/client-key.pem \
		-v ${PWD}/certs/apiserver/certs/apiserver-localhost.pem:/etc/ssl/apiserver.pem \
		-v ${PWD}/certs/apiserver/certs/apiserver-localhost-key.pem:/etc/ssl/apiserver-key.pem \
		-v ${PWD}/certs/controller/controller-key.pem:/etc/ssl/controller-key.pem \
		${HYPERKUBE_IMAGE_REPO}:$K8S_VER /hyperkube \
		apiserver \
		--etcd-cafile=/etc/ssl/ca.pem \
		--etcd-certfile=/etc/ssl/etcd/client.pem \
		--etcd-keyfile=/etc/ssl/etcd/client-key.pem \
		--etcd-servers=${ETCD_ENDPOINTS} \
		--allow-privileged=true \
		--service-cluster-ip-range=${SERVICE_IP_RANGE}  \
		--insecure-bind-address=0.0.0.0 \
		--insecure-port=8080 \
		--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds \
		--tls-cert-file=/etc/ssl/apiserver.pem \
		--tls-private-key-file=/etc/ssl/apiserver-key.pem \
		--client-ca-file=/etc/ssl/ca.pem \
		--service-account-key-file=/etc/ssl/controller-key.pem \
		--runtime-config=extensions/v1beta1/networkpolicies=true

	echo "Waiting for Kubernetes API..."
	until curl --silent "http://127.0.0.1:8080/version"; do
		sleep 5
	done

	echo "Installing Kube-DNS"
	docker run --rm --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/kube-dns
	echo "Installing Heapster"
	docker run --rm --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/heapster
	echo "Installing Kubernetes-dashboard"
	docker run --rm --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/kubernetes-dashboard

	echo "Removing local apiserver"
	docker stop k8s-bootstrap

}
