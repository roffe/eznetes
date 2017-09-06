#!/bin/bash
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