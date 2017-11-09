#!/bin/bash

function create_admin_cert() {
	local CN=${1:-admin}
	local O=${2:-system:masters}
	echo "CN ${CN} O ${O}"
	mkdir -p certs/admin
	openssl genrsa -out ${CN}-key.pem 2048
	openssl req -new -key ${CN}-key.pem -out ${CN}.csr -subj "/CN=${CN}/O=${O}"
	openssl x509 -req -in ${CN}.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out ${CN}.pem -days 365
	rm -f ${CN}.csr
}

function create_metrics-server_cert() {
	mkdir -p certs/aggregator/certs
	
	if [ ! -f "certs/aggregator/certs/ca-aggregator.key" ]; then
		openssl req -x509 -sha256 -new -nodes -days 3650 -newkey rsa:2048 -keyout certs/aggregator/certs/ca-aggregator.key -out certs/aggregator/certs/ca-aggregator.crt -subj "/CN=ca"
	else
		echo "ca-aggregator.key already exists, skipping"
	fi

	export PURPOSE=server
	echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","'${PURPOSE}'"]}}}' > "certs/aggregator/certs/${PURPOSE}-ca-config.json"
	export SERVICE_NAME=metrics-server
	export ALT_NAMES='"metrics-server.kube-system","metrics-server.kube-system.svc","metrics-server.kube-system.svc.cluster.local"'
	
	if [ ! -f "certs/aggregator/certs/metrics-server-key.pem" ]; then
	echo '{"CN":"'${SERVICE_NAME}'","hosts":['${ALT_NAMES}'],"key":{"algo":"rsa","size":2048}}' | \
		cfssl gencert -ca=certs/aggregator/certs/ca-aggregator.crt -ca-key=certs/aggregator/certs/ca-aggregator.key -config=certs/aggregator/certs/${PURPOSE}-ca-config.json - | \
		cfssljson -bare certs/aggregator/certs/metrics-server
	else
		echo "metrics-server-key.pem already exists, skipping!"
	fi

	if [ ! -f "certs/aggregator/certs/proxy-client-key.pem" ]; then
	echo '{"CN":"'aggregator'","key":{"algo":"rsa","size":2048}}' | \
		cfssl gencert -ca=certs/aggregator/certs/ca-aggregator.crt -ca-key=certs/aggregator/certs/ca-aggregator.key -config=certs/aggregator/certs/server-ca-config.json - | \
		cfssljson -bare certs/aggregator/certs/proxy-client
	else
		echo "proxy-client-key.pem already exists, skipping!"
	fi
}

function create_apiserver_cert() {
	mkdir -p certs/apiserver/certs
	check_ca_exist
	if [[ ! -z ${1} ]] && [[ ! -z ${2} ]]; then

		local APISERVER_HOSTNAME=$(echo ${2} | cut -d'.' -f1)
		if [ ! -f "certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}-key.pem" ]; then
			echo "Generating apiserver private key"
			openssl genrsa -out certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}-key.pem 2048
		else
			echo "apiserver-${APISERVER_HOSTNAME}-key.pem exists, skipping creation"
		fi

		if [ ! -f "certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}.pem" ]; then
			echo "Generating apiserver cert"
			APISERVER_IP=${1} APISERVER_FQDN=${2} APISERVER_HOSTNAME=${APISERVER_HOSTNAME} APISERVER_LBFQDN=${APISERVER_LBFQDN} APISERVER_LBIP=${APISERVER_LBIP} openssl req -new -key certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}-key.pem -out certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}.csr -subj "/CN=kube-apiserver" -config certs/apiserver/cnf/apiserver.cnf
			APISERVER_IP=${1} APISERVER_FQDN=${2} APISERVER_HOSTNAME=${APISERVER_HOSTNAME} APISERVER_LBFQDN=${APISERVER_LBFQDN} APISERVER_LBIP=${APISERVER_LBIP} openssl x509 -req -in certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/apiserver/certs/apiserver-${APISERVER_HOSTNAME}.pem -days 3650 -extensions v3_req -extfile certs/apiserver/cnf/apiserver.cnf
		else
			echo "apiserver-${APISERVER_HOSTNAME}.pem exists, skipping creation"
		fi
	else
		echo "Missing parameters, Usage: ${0} <ip> <fqdn>"
	fi
}

function create_ca_cert() {
	mkdir -p certs/ca
	if [[ -f certs/ca/ca.pem ]] || [[ -f certs/ca/ca-key.pem ]]; then
		echo 'CA certificate already exists, please remove "certs/ca/ca.pem" & "ca-key.pem" to create new'
	else
		echo "Creating CA key & cert"
		openssl genrsa -out certs/ca/ca-key.pem 2048
		openssl req -x509 -new -nodes -key certs/ca/ca-key.pem -days 3650 -out certs/ca/ca.pem -subj "/CN=kube-ca"
	fi
}

function create_controller_cert() {
	mkdir -p certs/controller
	if [ ! -f certs/controller/controller-key.pem ]; then
		echo "Generatig kube-controller-manager private key"
		openssl genrsa -out certs/controller/controller-key.pem 2048
	else
		echo "kube-controller-manager private key exists, skipping creation"
	fi

	if [ ! -f certs/controller/controller.pem ]; then
		echo "Generatig kube-controller-manager cert"
		openssl req -new -key certs/controller/controller-key.pem -out certs/controller/controller.csr -subj "/CN=system:kube-controller-manager"
		openssl x509 -req -in certs/controller/controller.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/controller/controller.pem -days 3650
	else
		echo "kube-controller-manager cert exists, skipping creation"
	fi

}

function create_node_cert() {
	mkdir -p certs/node
	local NODE_HOSTNAME=$(echo ${2} | cut -d'.' -f1)

	if [ ! -f "certs/node/${NODE_HOSTNAME}-key.pem" ]; then
		echo "Generatig ${NODE_HOSTNAME} private key"
		openssl genrsa -out certs/node/${NODE_HOSTNAME}-key.pem 2048
	else
		echo "${NODE_HOSTNAME} private key exists, skipping creation"
	fi

	if [ ! -f "certs/node/${NODE_HOSTNAME}.pem" ]; then
		openssl req -new -key certs/node/${NODE_HOSTNAME}-key.pem -out certs/node/${NODE_HOSTNAME}.csr -subj "/O=system:nodes/CN=system:node:${1}"
		openssl x509 -req -in certs/node/${NODE_HOSTNAME}.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/node/${NODE_HOSTNAME}.pem -days 3650
	else
		echo "${NODE_HOSTNAME} cert exists, skipping creation"
	fi
}

function create_proxy_cert() {
	mkdir -p certs/proxy
	if [ ! -f certs/proxy/proxy-key.pem ]; then
		echo "Creating kube-proxy key"
		openssl genrsa -out certs/proxy/proxy-key.pem 2048
	else
		echo "kube-proxy private key exists, skippping creation"
	fi

	if [ ! -f certs/proxy/proxy.pem ]; then
		echo "Creating kube-proxy cert"
		openssl req -new -key certs/proxy/proxy-key.pem -out certs/proxy/proxy.csr -subj "/CN=system:kube-proxy"
		openssl x509 -req -in certs/proxy/proxy.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/proxy/proxy.pem -days 3650
	else
		echo "kube-proxy cert exists, skippping creation"
	fi
}

function create_scheduler_cert() {
	mkdir -p certs/scheduler
	if [ ! -f certs/scheduler/scheduler-key.pem ]; then
		openssl genrsa -out certs/scheduler/scheduler-key.pem 2048
	else
		echo "kube-scheduler private key exists, skippping creation"
	fi

	if [ ! -f certs/scheduler/scheduler.pem ]; then
		openssl req -new -key certs/scheduler/scheduler-key.pem -out certs/scheduler/scheduler.csr -subj "/CN=system:kube-scheduler"
		openssl x509 -req -in certs/scheduler/scheduler.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/scheduler/scheduler.pem -days 3650
	else
		echo "kube-scheduler cert exists, skippping creation"
	fi
}
