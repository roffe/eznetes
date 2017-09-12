openssl rand -base64 32 > weave-passwd
kubectl create secret -n kube-system generic weave-passwd --from-file=./weave-passwd
kubectl apply -f weave.yaml
