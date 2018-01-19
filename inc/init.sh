#!/bin/bash

# Start a insecure apiserver locally that we will use to add out first services & addons to kubernetes.
function init_k8s() {
	create_apiserver_cert "127.0.0.1" "localhost"
	echo "Starting local apiserver"
	docker run --rm -d --name k8s-bootstrap \
		-p 8989:8989 \
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
		--insecure-port=8989 \
		--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds \
		--tls-cert-file=/etc/ssl/apiserver.pem \
		--tls-private-key-file=/etc/ssl/apiserver-key.pem \
		--client-ca-file=/etc/ssl/ca.pem \
		--service-account-key-file=/etc/ssl/controller-key.pem \
		--runtime-config=extensions/v1beta1/networkpolicies=true,batch/v2alpha1=true

	echo "Waiting for Kubernetes API..."
	until curl --silent "http://127.0.0.1:8989/version"; do
		sleep 5
	done
	echo "Installing Kube-router"
	sed -e "s;%POD_NETWORK%;$POD_NETWORK;g" -e "s;%CONTROLLER_ENDPOINT%;$CONTROLLER_ENDPOINT;g" manifests/kube-router/daemonset.tmpl > manifests/kube-router/kube-router.yaml
	docker run --rm -ti --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/kube-router --server 127.0.0.1:8989
	echo "Installing Kube-DNS"
	docker run --rm -ti --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/kube-dns --server 127.0.0.1:8989
	echo "Installing Heapster"
	docker run --rm -ti --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/heapster --server 127.0.0.1:8989
	echo "Installing Kubernetes-dashboard"
	docker run --rm -ti --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/kubernetes-dashboard --server 127.0.0.1:8989
	echo "Creating RBAC roles for nodes automatic TLS handling"
	docker run --rm -ti --net=host -v ${PWD}/manifests:/manifests $HYPERKUBE_IMAGE_REPO:$K8S_VER /hyperkube kubectl apply -f /manifests/approvalcontroller --server 127.0.0.1:8989

	echo "Removing local apiserver"
	docker stop k8s-bootstrap

}
