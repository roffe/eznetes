#!/bin/bash
# Maintainer Joakim Karlsson <joakim@roffe.nu>

set -e

# trap ctrl-c, call ctrl_c() & Exit
trap deploy_exit INT EXIT

# Import settings
source settings.rc

# Load etcd specific functions
source inc/etcd.sh

# Load certificate creation specific functions
source inc/certs.sh

# Load functions for creating package
source inc/package.sh

# Load deployment related functions
source inc/deploy.sh

function check_ca_exist() {
	if [[ ! -f certs/ca/ca.pem ]] || [[ ! -f certs/ca/ca-key.pem ]]; then
		echo "Missing ca.pem or ca-key.pem, Please run: ${0} create-ca"
		exit 1
		# create_ca
	fi
}

function deploy_exit() {
        rm -rf ${TMPDIR}
		rm -f deploy.tgz
        exit 0
}

function delete_all_certificates {
	find certs -type f \( ! -iname "*.cnf" \) -exec rm {} \;
}

function test_ssh() {
	echo -n "SSH: "
	RES=`ssh -oBatchMode=yes -q ${USERNAME}@${1} "sudo echo 'ok'; exit"`
	if [ $? -eq 0 ]; then
		if [ "${RES}" == "ok" ]; then
			echo "OK"
			echo "Sudo over SSH: OK"
		else
			echo "SSH or Sudo error, check so you can SSH and sudo to destination host with cert login"
			exit 1
		fi
	else
		echo "Error, can't connect"
		exit 1
	fi
}

function usage() {
	case "${1}" in
		cert)
		echo "Usage: ${1} ${2} {admin|ca|etcd-server|etcd-client|kube-apiserver|kube-controller-manager|kube-proxy|kube-scheduler}"
		;;
		etcd)
		echo "Usage: ${1} ${2} <ip> <fqdn/hostname>"
		;;
		master)
		echo "Creates necessacry certificates and deploys kubernetes master node to destination"
		echo "Usage: ${1} ${2} <ip> <fqdn>"
		;;
		worker)
		echo "Creates necessacry certificates and deploys kubernetes worker node to destination"
		echo "Usage: ${1} ${2} <ip> <fqdn>"
		;;
		*)
	esac
}

TMPDIR=$(mktemp -d)

if [ -z ${USERNAME} ]; then
	# echo "Username not set, defaulting to \"core\""
	export USERNAME="core"
fi

case "${1}" in
	bootstrap-flannel)
		init_flannel
		;;
	
	etcd)
		if [[ ! -z ${2} ]] && [[ ! -z ${3} ]]; then
			etcd_deploy ${2} ${3}
		else
			usage $0 $1
		fi
		;;
	
	master)
        if [[ ! -z ${2} ]] && [[ ! -z ${3} ]]; then
			master_deploy ${2} ${3}
		else
			usage $0 $1
		fi
        ;;
    
	worker)
        if [[ ! -z ${2} ]] && [[ ! -z ${3} ]]; then
			worker_deploy ${2} ${3}
        else
			usage $1
		fi
		;;
	
	create-ca)
		create_ca
		;;
	
	cert)
		case "${2}" in
			admin)
				create_admin_cert
			;;
			ca)
				create_ca_cert
			;;
			etcd-server)
				create_etcd_server_cert ${3} ${4}
			;;
			etcd-client)
				create_etcd_client_cert
			;;
			kube-controller-manager)
				create_controller_cert
			;;
			kube-apiserver)
				create_apiserver_cert ${3} ${4}
			;;
			kube-proxy)
				create_proxy_cert
			;;
			kube-scheduler)
				create_scheduler_cert
			;;
			*)
			usage ${1}
		esac
		;;
	
	delete-all-certificates)
		delete_all_certificates
	;;
		
	*)
		echo $"Usage: $0 {master|worker|cert}"
esac












