#!bin/bash
function oidc_settings {
if [ "${OIDC_AUTH}" == "true" ]; then
  echo "    - --oidc-issuer-url=${OIDC_URL}"
  echo "    - --oidc-client-id=${OIDC_ID}"
  echo '    - --oidc-ca-file=/etc/kubernetes/ssl/ca.pem'
  echo '    - --oidc-username-claim=email'
  echo '    - --oidc-groups-claim=groups'
fi
}

function get_no_apiservers {
  echo -n "${K8S_MASTERS}"|awk -F',' '{print NF}'
}

function haproxy_backend_gen() {
	local arr=$(echo -n ${K8S_MASTERS} | tr "," "\n")
	local NO=00
  for MASTER in $arr; do
		NO=$((NO + 1))
		if [ "${MASTER}" == "${ADVERTISE_IP}" ]; then
			local M_IP=127.0.0.1
		else
			local M_IP=${MASTER}
		fi
		echo "server api$(printf %02d ${NO}) ${M_IP}:443 check check-ssl verify none"
	done

}

function keepalived_unicast_list {
	local arr=$(echo -n ${K8S_MASTERS} | tr "," "\n")
	local NO=00
	RES=$(for IP_N in $arr; do
		NO=$((NO + 1))
		echo -n "'${IP_N}',"
	done)
	echo -n ${RES} | sed 's/,$//'
}

local TEMPLATE=/etc/sysctl.d/nonlocal_bind.conf
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
net.ipv4.ip_nonlocal_bind=1
EOF
sudo sysctl -p ${TEMPLATE}

local TEMPLATE=/etc/kubernetes/haproxy.cfg
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
global
maxconn 8192
ssl-server-verify none
defaults
mode tcp
timeout connect 5000ms
timeout client 600000ms
timeout server 600000ms

# uncomment the following to enable haproxy stats webpage
# frontend stats_8888
# bind *:8888
# mode http
# maxconn 10
# stats enable
# stats hide-version
# stats refresh 30s
# stats show-node
# stats auth admin:password
# stats uri /haproxy?stats

frontend api_ssl
bind ${APISERVER_LBIP}:443
bind ${ADVERTISE_IP}:443
bind 127.0.0.1:8443
default_backend bk_api

backend bk_api
balance source
default-server inter 3s fall 2
$(haproxy_backend_gen)
EOF
local TEMPLATE=/etc/kubernetes/manifests/kube-apilb.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-apilb
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: keepalived
    image: osixia/keepalived:1.3.9
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
    env:
    - name: CREATED
      value: "$(date +%s)"
    - name: KEEPALIVED_VIRTUAL_IPS
      value: "#PYTHON2BASH:['${APISERVER_LBIP}']"
    - name: KEEPALIVED_UNICAST_PEERS
      value: "#PYTHON2BASH:[$(keepalived_unicast_list)]"
    - name: KEEPALIVED_INTERFACE
      value: $(echo -n $(ifconfig | grep -B1 "inet ${ADVERTISE_IP}" | awk '$1!="inet" && $1!="--" {print $1}' | tr -d ':'))
  - name: haproxy
    image: haproxy:1.7-alpine
    volumeMounts:
    - mountPath: /usr/local/etc/haproxy/haproxy.cfg
      name: kube-haproxycfg
      readOnly: true       
  volumes:
  - hostPath:
      path: /etc/kubernetes/haproxy.cfg
    name: kube-haproxycfg
EOF

local TEMPLATE=/etc/kubernetes/manifests/kube-apiserver.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: apiserver
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - apiserver
    - --apiserver-count=$(get_no_apiservers)
    - --bind-address=127.0.0.1
    - --etcd-cafile=/etc/kubernetes/ssl/ca.pem
    - --etcd-certfile=/etc/ssl/etcd/client.pem
    - --etcd-keyfile=/etc/ssl/etcd/client-key.pem
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --allow-privileged=true
    - --authorization-mode=RBAC,Node
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --secure-port=443
    - --advertise-address=${ADVERTISE_IP}
    - --admission-control=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds
    - --tls-ca-file=/etc/kubernetes/ssl/ca.pem
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver-${NODE_HOSTNAME}.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-${NODE_HOSTNAME}-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/controller-key.pem
    - --runtime-config=extensions/v1beta1/networkpolicies=true,authentication.k8s.io/v1beta1=true
    - --anonymous-auth=false
    - --enable-bootstrap-token-auth
    - --runtime-config=authentication.k8s.io/v1beta1=true
    - --feature-gates=RotateKubeletClientCertificate=true,RotateKubeletServerCertificate=true,AdvancedAuditing=false
    - --token-auth-file=/etc/kubernetes/ssl/bootstraptoken.csv
    - --audit-log-path=/var/log/audit/audit.log
    - --audit-log-maxage=7
    - --requestheader-client-ca-file=/etc/kubernetes/ssl/ca-aggregator.crt
    - --requestheader-allowed-names=aggregator
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --proxy-client-cert-file=/etc/kubernetes/ssl/proxy-client.pem
    - --proxy-client-key-file=/etc/kubernetes/ssl/proxy-client-key.pem
$(oidc_settings)
    env:
    - name: CREATED
      value: "$(date +%s)"
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        port: 8080
        path: /healthz
      initialDelaySeconds: 15
      timeoutSeconds: 15
    ports:
    - containerPort: 443
      hostPort: 443
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
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
    - mountPath: /var/log/audit
      name: "auditlogpath"
      readOnly: false
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - name: "etc-ssl-etcd"
    hostPath:
      path: "/etc/ssl/etcd"
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
  - hostPath:
      path: /var/log/audit
    name: auditlogpath
EOF
