#!/bin/bash
local TEMPLATE=/etc/kubernetes/manifests/kube-scheduler.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - scheduler
    - --master=https://127.0.0.1
    - --leader-elect=true
    - --kubeconfig=/etc/kubernetes/scheduler-kubeconfig.yaml
    resources:
      requests:
        cpu: 100m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: "etc-kube-ssl"
      readOnly: true
    - mountPath: /etc/kubernetes/scheduler-kubeconfig.yaml
      name: "kubeconfig"
      readOnly: true
  volumes:
  - name: "etc-kube-ssl"
    hostPath:
      path: "/etc/kubernetes/ssl"
  - name: "kubeconfig"
    hostPath:
      path: "/etc/kubernetes/scheduler-kubeconfig.yaml"
EOF