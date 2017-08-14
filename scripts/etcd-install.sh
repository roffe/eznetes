#!/bin/bash
set -e

mkdir -p /etc/ssl/etcd
mkdir -p /etc/kubernetes/ssl

mv ssl/client* /etc/ssl/etcd/
mv ssl/etcd/* /etc/ssl/etcd/
cp ssl/ca.pem /etc/ssl/etcd/

mv ssl/* /etc/kubernetes/ssl/


chmod 600 /etc/ssl/etcd/*-key.pem
chmod 600 /etc/kubernetes/ssl/*-key.pem

chown root:root /etc/ssl/etcd/*-key.pem
chown root:root /etc/kubernetes/ssl/*-key.pem

source settings.rc

# -------------

function init_config {
    local REQUIRED=( 'ADVERTISE_IP' 'ETCD_ENDPOINTS' 'CONTROLLER_ENDPOINT' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' 'USE_CALICO' 'MAX_PODS')

    if [ -z $MAX_PODS ]; then
        # Number of Pods that can run on this Kubelet. (default 110)
        export MAX_PODS=110
    fi

    if [ "${USE_CALICO}" = "true" ]; then
        export CALICO_OPTS="--volume cni-bin,kind=host,source=/opt/cni/bin \
                            --mount volume=cni-bin,target=/opt/cni/bin"
    else
        export CALICO_OPTS=""
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done
}

function etcd_initial_cluster_list {
    local arr=$(echo -n ${ETCD_ENDPOINTS} | tr "," "\n")
    local NO=00
    RES=$(for ETCD in $arr; do
        NO=$((NO+1))
        echo -n "${CLUSTER_NAME}-etcd$(printf %02d ${NO})=https:$(echo ${ETCD}|cut -d':' -f2):${ETCD_PEER_PORT},"
        done )
    echo ${RES} | sed 's/,$//'
}

function init_templates {
    local TEMPLATE=/etc/kubernetes/manifests/kube-etcd.yaml
    echo "TEMPLATE: $TEMPLATE"
    mkdir -p $(dirname $TEMPLATE)
    cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-etcd
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-etcd
    image: quay.io/coreos/etcd:v3.2
    command:
    - etcd
    - --config-file=/etc/etcd/etcd.yaml
    env:
    - name: GOMAXPROCS
      value: "2"
#    livenessProbe:
#      httpGet:
#        host: 127.0.0.1
#        port: 8080
#        path: /healthz
#      initialDelaySeconds: 15
#      timeoutSeconds: 15
    ports:
    - containerPort: 2380
      hostPort: 2380
      name: peer
    - containerPort: 2379
      hostPort: 2379
      name: client
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
    - mountPath: /etc/ssl/etcd
      name: "etc-ssl-etcd"
      readOnly: true
    - mountPath: /etc/etcd/etcd.yaml
      name: "etcd-conf"
      readOnly: true
    - mountPath: /data/etcd
      name: "data-etcd"
      readOnly: false
  volumes:
  - hostPath:
      path: /etc/etcd/etcd.yaml
    name: etcd-conf
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: "/etc/ssl/etcd"
    name: "etc-ssl-etcd"
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
  - hostPath:
      path: /data/etcd
    name: data-etcd
EOF



    local TEMPLATE=/etc/etcd/etcd.yaml
    echo "TEMPLATE: $TEMPLATE"
    mkdir -p $(dirname $TEMPLATE)
    cat << EOF > $TEMPLATE
name: '${NODE_HOSTNAME}'
data-dir: /data/etcd
wal-dir:
snapshot-count: 10000
heartbeat-interval: 100
election-timeout: 1000
quota-backend-bytes: 0
listen-peer-urls: https://0.0.0.0:${ETCD_PEER_PORT}
listen-client-urls: https://0.0.0.0:${ETCD_CLIENT_PORT}
max-snapshots: 5
max-wals: 5
cors:
initial-advertise-peer-urls: https://${ADVERTISE_IP}:${ETCD_PEER_PORT}
advertise-client-urls: https://${ADVERTISE_IP}:${ETCD_CLIENT_PORT}
discovery:
discovery-fallback: 'proxy'
discovery-proxy:
discovery-srv:
initial-cluster: $(etcd_initial_cluster_list)
initial-cluster-token: '${ETCD_CLUSTER_TOKEN}'
initial-cluster-state: 'new'
strict-reconfig-check: true
enable-v2: true
proxy: 'off'
proxy-failure-wait: 5000
proxy-refresh-interval: 30000
proxy-dial-timeout: 1000
proxy-write-timeout: 5000
proxy-read-timeout: 0
client-transport-security:
  cert-file: /etc/ssl/etcd/${NODE_HOSTNAME}.pem
  key-file: /etc/ssl/etcd/${NODE_HOSTNAME}-key.pem
  client-cert-auth: true
  trusted-ca-file: /etc/ssl/etcd/ca.pem
  auto-tls: false
peer-transport-security:
  cert-file: /etc/ssl/etcd/${NODE_HOSTNAME}-peer.pem
  key-file: /etc/ssl/etcd/${NODE_HOSTNAME}-peer-key.pem
  client-cert-auth: true
  trusted-ca-file: /etc/ssl/etcd/ca.pem
  auto-tls: false
debug: false
log-package-levels:
force-new-cluster: false
EOF

    local TEMPLATE=/etc/docker/daemon.json
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
    "live-restore": true
}
EOF

    local TEMPLATE=/etc/systemd/system/kubelet.service
    local uuid_file="/var/run/kubelet-pod.uuid"
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
Environment=KUBELET_IMAGE_TAG=${K8S_VER}
Environment=KUBELET_IMAGE_URL=docker://${HYPERKUBE_IMAGE_REPO}
Environment="RKT_RUN_ARGS=--insecure-options=image \
  --uuid-file-save=${uuid_file} \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf \
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
  ${CALICO_OPTS}"
ExecStartPre=/usr/bin/mkdir -p /var/lib/cni
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers
ExecStartPre=-/usr/bin/rkt rm --uuid-file=${uuid_file}
ExecStartPre=/usr/bin/mkdir -p /opt/cni/bin
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --api-servers=${CONTROLLER_ENDPOINT} \
  --cni-conf-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=cni \
  --container-runtime=${CONTAINER_RUNTIME} \
  --rkt-path=/usr/bin/rkt \
  --rkt-stage1-image=coreos.com/rkt/stage1-fly \
  --register-with-taints="node-role.kubernetes.io/etcd=:NoSchedule" \
  --register-node=true \
  --max-pods=${MAX_PODS} \
  --allow-privileged=true \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster-dns=${DNS_SERVICE_IP} \
  --cluster-domain=cluster.local \
  --kubeconfig=/etc/kubernetes/etcd-kubeconfig.yaml
ExecStop=-/usr/bin/rkt stop --uuid-file=${uuid_file}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    local TEMPLATE=/opt/bin/host-rkt
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
#!/bin/sh
# This is bind mounted into the kubelet rootfs and all rkt shell-outs go
# through this rkt wrapper. It essentially enters the host mount namespace
# (which it is already in) only for the purpose of breaking out of the chroot
# before calling rkt. It makes things like rkt gc work and avoids bind mounting
# in certain rkt filesystem dependancies into the kubelet rootfs. This can
# eventually be obviated when the write-api stuff gets upstream and rkt gc is
# through the api-server. Related issue:
# https://github.com/coreos/rkt/issues/2878
exec nsenter -m -u -i -n -p -t 1 -- /usr/bin/rkt "\$@"
EOF

    local TEMPLATE=/etc/systemd/system/load-rkt-stage1.service
    if [ ${CONTAINER_RUNTIME} = "rkt" ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Description=Load rkt stage1 images
Documentation=http://github.com/coreos/rkt
Requires=network-online.target
After=network-online.target
Before=rkt-api.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/rkt fetch /usr/lib/rkt/stage1-images/stage1-coreos.aci /usr/lib/rkt/stage1-images/stage1-fly.aci  --insecure-options=image

[Install]
RequiredBy=rkt-api.service
EOF
    fi

    local TEMPLATE=/etc/systemd/system/rkt-api.service
    if [ ${CONTAINER_RUNTIME} = "rkt" ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Before=kubelet.service

[Service]
ExecStart=/usr/bin/rkt api-service
Restart=always
RestartSec=10

[Install]
RequiredBy=kubelet.service
EOF
    fi

    local TEMPLATE=/etc/kubernetes/etcd-kubeconfig.yaml
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
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


    local TEMPLATE=/etc/kubernetes/proxy-kubeconfig.yaml
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
users:
- name: kube-proxy
  user:
    client-certificate: /etc/kubernetes/ssl/proxy.pem
    client-key: /etc/kubernetes/ssl/proxy-key.pem
contexts:
- context:
    cluster: local
    user: kube-proxy
  name: kube-proxy-context
current-context: kube-proxy-context
EOF

    local TEMPLATE=/etc/kubernetes/manifests/kube-proxy.yaml
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
  annotations:
    rkt.alpha.kubernetes.io/stage1-name-override: coreos.com/rkt/stage1-fly
spec:
  hostNetwork: true
  containers:
  - name: kube-proxy
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - proxy
    - --master=${CONTROLLER_ENDPOINT}
    - --cluster-cidr=${POD_NETWORK}
    - --hostname-override=${ADVERTISE_IP}
    - --kubeconfig=/etc/kubernetes/proxy-kubeconfig.yaml
    securityContext:
      privileged: true
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10256
      initialDelaySeconds: 15
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: "ssl-certs"
    - mountPath: /etc/kubernetes/proxy-kubeconfig.yaml
      name: "kubeconfig"
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: "etc-kube-ssl"
      readOnly: true
    - mountPath: /var/run/dbus
      name: dbus
      readOnly: false
  volumes:
  - name: "ssl-certs"
    hostPath:
      path: "/usr/share/ca-certificates"
  - name: "kubeconfig"
    hostPath:
      path: "/etc/kubernetes/proxy-kubeconfig.yaml"
  - name: "etc-kube-ssl"
    hostPath:
      path: "/etc/kubernetes/ssl"
  - hostPath:
      path: /var/run/dbus
    name: dbus
EOF

    local TEMPLATE=/etc/flannel/options.env
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
FLANNELD_IFACE=$ADVERTISE_IP
FLANNELD_ETCD_ENDPOINTS=$ETCD_ENDPOINTS
FLANNELD_ETCD_CAFILE=/etc/ssl/etcd/ca.pem
FLANNELD_ETCD_CERTFILE=/etc/ssl/etcd/client.pem
FLANNELD_ETCD_KEYFILE=/etc/ssl/etcd/client-key.pem
EOF

    local TEMPLATE=/etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf.conf
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
EOF

    local TEMPLATE=/etc/systemd/system/docker.service.d/40-flannel.conf
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Requires=flanneld.service
After=flanneld.service
[Service]
EnvironmentFile=/etc/kubernetes/cni/docker_opts_cni.env
EOF

    local TEMPLATE=/etc/kubernetes/cni/docker_opts_cni.env
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
DOCKER_OPT_BIP=""
DOCKER_OPT_IPMASQ=""
EOF


    local TEMPLATE=/etc/kubernetes/cni/net.d/10-flannel.conf
    if [ "${USE_CALICO}" = "false" ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
    "name": "podnet",
    "type": "flannel",
    "delegate": {
        "isDefaultGateway": true
    }
}
EOF

    
    fi
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
fi

echo "Restarting Flannel"
systemctl enable flanneld; systemctl restart flanneld

echo "Restarting Kubelet"
systemctl enable kubelet; systemctl restart kubelet

echo "**You must SSH to the node(s) and change `initial-cluster-state: 'new'` to `initial-cluster-state: 'existing'` in `/etc/etcd/etcd.yaml` once initial cluster state is reached for restarts of ETCD to work properly**"
echo "DONE"