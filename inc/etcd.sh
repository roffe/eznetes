#!/bin/bash

function create_etcd_server_cert() {
	check_ca_exist
	if [[ ! -z ${1} ]] && [[ ! -z ${2} ]]; then
		mkdir -p certs/etcd/server
		local ETCD_HOSTNAME=$(echo ${2} | cut -d'.' -f1)
		if [ ! -f certs/etcd/server/${ETCD_HOSTNAME}-key.pem ]; then
			openssl genrsa -out certs/etcd/server/${ETCD_HOSTNAME}-key.pem 2048
		else
			echo "etcd/${ETCD_HOSTNAME} private key exists, skipping creation"
		fi

		if [ ! -f certs/etcd/server/${ETCD_HOSTNAME}.pem ]; then
			ETCD_HOSTNAME=${ETCD_HOSTNAME} ETCD_IP=${1} ETCD_FQDN=${2} openssl req -new -key certs/etcd/server/${ETCD_HOSTNAME}-key.pem -out certs/etcd/server/${ETCD_HOSTNAME}.csr -subj "/CN=${2}" -config certs/etcd/cnf/server.cnf
			ETCD_HOSTNAME=${ETCD_HOSTNAME} ETCD_IP=${1} ETCD_FQDN=${2} openssl x509 -req -in certs/etcd/server/${ETCD_HOSTNAME}.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/etcd/server/${ETCD_HOSTNAME}.pem -days 3650 -extensions v3_req -extfile certs/etcd/cnf/server.cnf
		else
			echo "etcd/${ETCD_HOSTNAME} cert exists, skipping creation"
		fi

		if [ ! -f certs/etcd/server/${ETCD_HOSTNAME}-peer-key.pem ]; then
			openssl genrsa -out certs/etcd/server/${ETCD_HOSTNAME}-peer-key.pem 2048
		else
			echo "etcd/${ETCD_HOSTNAME} peer key exists, skipping creation"
		fi

		if [ ! -f certs/etcd/server/${ETCD_HOSTNAME}-peer.pem ]; then
			ETCD_HOSTNAME=${ETCD_HOSTNAME} ETCD_IP=${1} ETCD_FQDN=${2} openssl req -new -key certs/etcd/server/${ETCD_HOSTNAME}-peer-key.pem -out certs/etcd/server/${ETCD_HOSTNAME}-peer.csr -subj "/CN=${2}" -config certs/etcd/cnf/peer.cnf
			ETCD_HOSTNAME=${ETCD_HOSTNAME} ETCD_IP=${1} ETCD_FQDN=${2} openssl x509 -req -in certs/etcd/server/${ETCD_HOSTNAME}-peer.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/etcd/server/${ETCD_HOSTNAME}-peer.pem -days 3650 -extensions v3_req -extfile certs/etcd/cnf/peer.cnf
		else
			echo "etcd/${ETCD_HOSTNAME} peer cert exists, skipping creation"
		fi
	else
		echo "2 parameters required"
		echo "Usage: ${0} cert etcd-server <ip> <fqdn>"
	fi
}

create_etcd_client_cert() {
	mkdir -p certs/etcd/client
	check_ca_exist
	if [ ! -f certs/etcd/client/client-key.pem ]; then
		openssl genrsa -out certs/etcd/client/client-key.pem 2048
	else
		echo "etcd/client-key.pem exists, skipping creation"
	fi

	if [ ! -f certs/etcd/client/client.pem ]; then
		openssl req -new -key certs/etcd/client/client-key.pem -out certs/etcd/client/client.csr -subj "/CN=etcd-client" -config certs/etcd/cnf/client.cnf
		openssl x509 -req -in certs/etcd/client/client.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca-key.pem -CAcreateserial -out certs/etcd/client/client.pem -days 3650 -extensions v3_req -extfile certs/etcd/cnf/client.cnf
	else
		echo "etcd/client.pem exists, skipping creation"
	fi
}
