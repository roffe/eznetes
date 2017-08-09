# Kubernetes the hard way
CoreOS edition by Joakim "Roffe" Karlsson

_**-> WIP WIP WIP WIP WIP WIP <-**_

This repo is not meant to be someones first shoot at Kubernetes, it's intended for power users who already has experience and want's to deploy Kubernetes as close to "from scratch" as possible

Original idea and alot of code inspiration / snippets comes from https://github.com/coreos/coreos-kubernetes and has thus inherited it's license

Pullrequests & ideas is always welcome!

## Todo
* Better documentation
* Bootstrap to be able to fire of and create manifests on the newly deployed cluster
...

## Prerequisites
* Working network where all the nodes can talk to each other directly
* Loadbalancer for apiserver(s)(Out of this docs scope, but a small example haproxy is provided below)
* 1, 3 or 5 CoreOS machines for ETCD (A very basic one-time bootstrap is offered by this repo)
* N+1 CoreOS machines for K8S masters
* N CoreOS Machines for K8S workers
* Copy settings.rc.sample to settings.rc and fill with your values

## Create root CA
To create the CA and CA key run:
`./deploy cert ca`

## Deploy ETCD
Deployment of ETCD can be done in a "one-off" command or you can have `deploy.sh` generate the certs needed and setup ETCD youself.

This tool provides no support for maintaining ETCD, how to upgrade it or how to debug.  
Questions regarding ETCD should be directed to the authors or relevant support channels

For the flannel bootstrap & master install to work the ETCD client cert's must be present under `certs/etcd/client/client.pem & client-key.pem` and the root ca in `certs/ca/ca.pem & ca-key.pem`

If you wish to manually deploy ETCD yourself it's recommended to have this script generate the certs and that you keep them in the original location so the deployment functions works as intended

#### By using deploy.sh
Repeat for each ETCD server.

Upon deploy, server & peer certs will be created from CA.

`./deploy etcd <ip> <fqdn or hostname>`

**You must SSH to the node(s) and change `initial-cluster-state: 'new'`to `initial-cluster-state: 'existing'` in `/etc/etcd/etcd.yaml` once initial cluster state is reached for restarts of ETCD to work properly**

#### Create ETCD server certificates
The following command will create a ETCD server & PEER cert in the `certs/etcd/server` folder

`./deploy.sh cert etcd-server <ip> <fqdn>`

#### Create ETCD client certificate
The following command will create a ETCD client cert in the `certs/etcd/client` folder

`./deploy.sh cert etcd-client`

## Bootstrap flannel setings once
Will set the podnetwork range for flannel in ETCD, See `inc/flannel.sh`

`./deploy.sh bootstrap-flannel`

## Deploy K8S master

Repeat for each master, additional masters can be added and removed at any point in time

`./deploy master <ip>  <fqdn or hostname>`

## Deploy K8S worker
Repeat for each worker, additional workers can be added and removed at any point in time

`./deploy master <ip>  <fqdn or hostname>`

## Create admin cert ( to use with kubectl )
Run the following command to create a cert with CN=admin O=system:master

`./deploy cert admin`

Files will be created in `certs/admin`

**The certs are then to be copied to your kubectl config folder and can be used to authenticate to the cluster.**

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.pem
    server: https://k8s-apiserverlb.example.com
  name: cluster01
contexts:
- context:
    cluster: cluster01
    user: admin
  name: cluster01
current-context: cluster01
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate: admin.pem
    client-key: admin-key.pem
```

For further instructions please see: https://kubernetes.io/docs/tasks/tools/install-kubectl/

## Manifests folder
Contains deployments for `heapster`, `kube-dns` & `kubernetes-dashboard`.

`Kube-DNS` deployment differs from the standard way as it's deployed with 3 services and 3 replicas,
then kublets is configured with 3 DNS servers in `--cluster-dns` for redundancy.

## Apiserver loadbalancer example
#### Haproxy

```text
global
    maxconn 1024
    ssl-server-verify none

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend stats_8888
    bind *:8888
    mode http
    maxconn 10
    stats enable
    stats hide-version
    stats refresh 30s
    stats show-node
    stats auth admin:changem3!
    stats uri /haproxy?stats


frontend api_ssl
    bind 0.0.0.0:443
    default_backend bk_api

backend bk_api
    balance source
    default-server inter 3s fall 2
    server api1 10.0.0.1:443 check check-ssl verify none
    server api1 10.0.0.2:443 check check-ssl verify none
    server api1 10.0.0.3:443 check check-ssl verify none
```
