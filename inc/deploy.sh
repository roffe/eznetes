#!/bin/bash
function master_deploy() {
	check_ca_exist
	create_apiserver_cert ${1} ${2}
	create_controller_cert
	create_proxy_cert
	create_scheduler_cert
	create_node_cert ${1} $2}
	create_etcd_client_cert
	build_package ${FUNCNAME} ${1} ${2}
	echo "Deploying master on ${1}"
	scp -q deploy.tgz ${USERNAME}@${1}:~/
	ssh -q ${USERNAME}@${1} 'bash -c "tar xzf deploy.tgz && sudo ./install.sh && rm -rf settings.rc install.sh ssl deploy.tgz inc"'
}

function worker_deploy() {
	local NODE_HOSTNAME=$(echo ${2} | cut -d'.' -f1)
	test_ssh $1
	check_ca_exist
	create_proxy_cert
	create_node_cert ${1} ${2}
	create_etcd_client_cert
	build_package ${FUNCNAME} ${1} ${2}
	echo "Deploying worker on: ${1}"
	scp -q deploy.tgz ${USERNAME}@${1}:~/
	ssh -q ${USERNAME}@${1} 'bash -c "tar xzf deploy.tgz && sudo ./install.sh && rm -rf settings.rc install.sh ssl deploy.tgz inc"'
}

function etcd_deploy() {
	local NODE_HOSTNAME=$(echo ${2} | cut -d'.' -f1)
	check_ca_exist
	create_proxy_cert
	create_etcd_server_cert ${1} ${2}
	create_node_cert ${1} ${2}
	build_package ${FUNCNAME} ${1} ${2}
	echo "Deploying etcd on: ${1}"
	scp -q deploy.tgz ${USERNAME}@${1}:~/
	ssh -q ${USERNAME}@${1} 'bash -c "tar xzf deploy.tgz && sudo ./install.sh && rm -rf settings.rc install.sh ssl deploy.tgz inc"'
}
