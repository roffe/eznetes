#!/bin/bash

local TEMPLATE=/etc/kubernetes/manifests/kube-etcd.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
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
cat <<EOF >$TEMPLATE
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