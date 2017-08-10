#!/bin/bash
function build_package() {
	local NODE_HOSTNAME=$(echo ${3} | cut -d'.' -f1)
	case "${1}" in
		etcd_deploy)
			echo "Building ETCD package"
			mkdir -p ${TMPDIR}/ssl/etcd
			cp certs/ca/ca.pem ${TMPDIR}/ssl/
			cp certs/node/${NODE_HOSTNAME}*.pem ${TMPDIR}/ssl/
			cp certs/proxy/proxy*.pem ${TMPDIR}/ssl/
			cp certs/etcd/server/${NODE_HOSTNAME}*.pem ${TMPDIR}/ssl/etcd
			cp certs/etcd/client/client*.pem ${TMPDIR}/ssl/
			cp scripts/etcd-install.sh ${TMPDIR}/install.sh
			cp settings.rc ${TMPDIR}/
			build_package_addsettings ${2} ${NODE_HOSTNAME}
			tar czf deploy.tgz -C ${TMPDIR} .
		;;
		
		master_deploy)
			echo "Building master package"
			mkdir -p ${TMPDIR}/ssl
			cp certs/ca/ca.pem ${TMPDIR}/ssl/
			cp certs/node/${NODE_HOSTNAME}*.pem ${TMPDIR}/ssl/
			cp certs/proxy/proxy*.pem ${TMPDIR}/ssl/
			cp certs/apiserver/certs/apiserver-${NODE_HOSTNAME}*.pem ${TMPDIR}/ssl/
			cp certs/controller/controller*.pem ${TMPDIR}/ssl/
			cp certs/scheduler/scheduler*.pem ${TMPDIR}/ssl/
			cp certs/etcd/client/client*.pem ${TMPDIR}/ssl/
			cp scripts/master-install.sh ${TMPDIR}/install.sh
			cp settings.rc ${TMPDIR}/
			build_package_addsettings ${2} ${NODE_HOSTNAME}
			tar czf deploy.tgz -C ${TMPDIR} .
		;;

		worker_deploy)
			echo "Building worker package"
			mkdir -p ${TMPDIR}/ssl
			cp certs/ca/ca.pem ${TMPDIR}/ssl/
			cp certs/node/${NODE_HOSTNAME}*.pem ${TMPDIR}/ssl/
			cp certs/proxy/proxy*.pem ${TMPDIR}/ssl/
			cp certs/etcd/client/client*.pem ${TMPDIR}/ssl/
			cp scripts/worker-install.sh ${TMPDIR}/install.sh
			cp settings.rc ${TMPDIR}/
			build_package_addsettings ${2} ${NODE_HOSTNAME}
			tar czf deploy.tgz -C ${TMPDIR} .
		;;
	esac
}

function build_package_addsettings() {
			echo "Adding node specific settings"
			echo "export ADVERTISE_IP=${1}" >> ${TMPDIR}/settings.rc
			echo "export NODE_HOSTNAME=${NODE_HOSTNAME}" >> ${TMPDIR}/settings.rc
}