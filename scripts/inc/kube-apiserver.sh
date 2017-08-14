#!bin/bash

local TEMPLATE=/etc/kubernetes/manifests/kube-apiserver.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - apiserver
    - --apiserver-count=2
    - --bind-address=0.0.0.0
    - --etcd-cafile=/etc/kubernetes/ssl/ca.pem
    - --etcd-certfile=/etc/ssl/etcd/client.pem
    - --etcd-keyfile=/etc/ssl/etcd/client-key.pem
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --secure-port=443
    - --advertise-address=${ADVERTISE_IP}
    - --admission-control=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver-${NODE_HOSTNAME}.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-${NODE_HOSTNAME}-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/controller-key.pem
    - --runtime-config=extensions/v1beta1/networkpolicies=true
    - --anonymous-auth=false
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
EOF