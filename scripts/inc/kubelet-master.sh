#!/bin/bash
local TEMPLATE=/etc/kubernetes/master-kubeconfig.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
    server: https://127.0.0.1
users:
- name: kubelet
  user:
    client-certificate: /etc/kubernetes/ssl/${NODE_HOSTNAME}.pem
    client-key: /etc/kubernetes/ssl/${NODE_HOSTNAME}-key.pem
contexts:
- context:
    cluster: local
    user: kubelet
  name: kubelet-context
current-context: kubelet-context
EOF

local TEMPLATE=/etc/systemd/system/kubelet.service
local uuid_file="/var/run/kubelet-pod.uuid"
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
[Service]
Environment=KUBELET_IMAGE_TAG=${K8S_VER}
Environment=KUBELET_IMAGE_URL=docker://${HYPERKUBE_IMAGE_REPO}
Environment=KUBELET_IMAGE_ARGS=--environment=home=/root \
Environment="RKT_RUN_ARGS=--insecure-options=image \
  --uuid-file-save=${uuid_file} \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf \
  --volume dockercfg,kind=host,source=/etc/docker/config.json \
  --mount volume=dockercfg,target=/root/.docker/config.json \
  --volume rkt,kind=host,source=/opt/bin/host-rkt \
  --mount volume=rkt,target=/usr/bin/rkt \
  --volume var-lib-rkt,kind=host,source=/var/lib/rkt \
  --mount volume=var-lib-rkt,target=/var/lib/rkt \
  --volume var-lib-cni,kind=host,source=/var/lib/cni \
  --mount volume=var-lib-cni,target=/var/lib/cni \
  --volume stage,kind=host,source=/tmp \
  --mount volume=stage,target=/tmp \
  --volume var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log \
  --volume etc-cni,kind=host,source=/etc/cni \
  --mount volume=etc-cni,target=/etc/cni \
  ${CNI_OPTS}"
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/lib/cni
ExecStartPre=/usr/bin/mkdir -p /opt/cni/bin
ExecStartPre=/usr/bin/mkdir -p /etc/cni
ExecStartPre=/usr/bin/mkdir -p /var/log/containers
ExecStartPre=-/usr/bin/rkt rm --uuid-file=${uuid_file}
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --register-with-taints="node-role.kubernetes.io/master=:NoSchedule" \
  --cni-conf-dir=/etc/cni/net.d \
  --network-plugin=cni \
  --container-runtime=${CONTAINER_RUNTIME} \
  --rkt-path=/usr/bin/rkt \
  --rkt-stage1-image=coreos.com/rkt/stage1-fly \
  --node-status-update-frequency=4s \
  --allow-privileged=true \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster-dns=${DNS_SERVICE_IP} \
  --cluster-domain=${CLUSTER_DOMAIN} \
  --kubeconfig=/etc/kubernetes/master-kubeconfig.yaml
ExecStop=-/usr/bin/rkt stop --uuid-file=${uuid_file}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
