# Kubernetes the semi-hard way

CoreOS edition by Joakim "Roffe" Karlsson

_**-> WIP WIP WIP WIP WIP WIP <-**_

This repo is not meant to be someones first shoot at Kubernetes, it's intended for power users who already has experience and want's to deploy Kubernetes "from scratch".

The goal of this project is to provide all the manuall steps needed to start a kubernetes cluster in a semi automated fashion.

_*I pledge to the furthest extent possible to keep all code & manifest in SHELLSCRIPT & YAML for maximal readability by as many people as possible*_

Original idea and alot of code inspiration / snippets comes from
[this repo](https://github.com/coreos/coreos-kubernetes) & [these](https://coreos.com/kubernetes/docs/latest/kubernetes-on-generic-platforms.html) instructions from [CoreOS](https://coreos.com) and has thus inherited it's license

Pullrequests & ideas is always welcome!

## Todo

* Better documentation
* Video guide & presentation
* More testing in the wild
* Template Kube-DNS addon to obeys `SERVICE_IP_RANGE` & `CLUSTER_DOMAIN`

## Known limitations

If you change the `SERVICE_IP_RANGE` be sure to update the `K8S_SERVICE_IP` & `DNS_SERVICE_IP` in settings.rc,

Also the templates in `manifests/` will need to be manualy patched at this moment when changing service CIDR

## Before you begin

* Working network where all the nodes can talk to each other directly
* 1, 3 or 5 CoreOS machines for ETCD (A very basic one-time bootstrap is offered by this repo)
* N+1 CoreOS machines for K8S masters
* N CoreOS Machines for K8S workers

## Instructions

* Copy settings.rc.sample to settings.rc and propagate with settings
* Create root CA (`./deploy cert ca`)
* Create VM's / Install Physichal machines
* Install CoreOS & configure basic networking between all the nodes
* Deploy ETCD (`./deploy.sh etcd <ip> <fqdn>`)
* Deploy Masters (`./deploy.sh master <ip> <fqdn>`)
* Deploy Workers (`./deploy.sh worker <ip> <fqdn>`)
* Install addons from manifest folder (`./deploy.sh install-addons`)
* Configure kubectl

## Deploy ETCD

Deployment of ETCD can be done in a "one-off" command or you can have `deploy.sh` generate the certs needed and setup ETCD youself.

This tool provides no support for maintaining ETCD, how to upgrade it or how to debug. Questions regarding ETCD should be directed to the authors or relevant support channels

For the master install to work the ETCD client cert's must be present under `/etc/certs/etcd/client/client.pem & client-key.pem` and the root ca in `/etc/certs/ca/ca.pem & ca-key.pem`

If you wish to manually deploy ETCD yourself it's recommended to have this script generate the certs and that you keep them in the original location so the deployment functions works as intended

Upon deploy, server & peer certs will be created from CA.

Repeat for each ETCD server:

    ./deploy etcd <ip> <fqdn or hostname>

**You must SSH to the node(s) and change `initial-cluster-state: 'new'`to `initial-cluster-state: 'existing'` in `/etc/etcd/etcd.yaml` once initial cluster state is reached for restarts of ETCD to work properly**

### Create ETCD server certificates

The following command will create a ETCD server & PEER cert in the `certs/etcd/server` folder

    ./deploy.sh cert etcd-server <ip> <fqdn>

### Create ETCD client certificate

The following command will create a ETCD client cert in the `certs/etcd/client` folder

    ./deploy.sh cert etcd-client

## Deploy K8S master

Repeat for each master, additional masters can be added and removed at any point in time.

A master node consists of: OS, Docker, Kubelet, kube-router, kube-apiserver, kube-controller-manager & kube-scheduler.

    ./deploy master <ip>  <fqdn or hostname>

## Deploy K8S worker

Repeat for each worker, additional workers can be added and removed at any point in time.

A worker node consists of: OS, Docker, Kubelet & kube-router.

    ./deploy worker <ip>  <fqdn or hostname>

## Create admin cert ( to use with kubectl )

Run the following command to create a cert with CN=admin O=system:master

    ./deploy cert admin

Files will be created in `certs/admin`

**The certs are then to be copied to your kubectl config folder and can be used to authenticate to the cluster.**

## Configure Kubectl

Below is a sample of how a kubectl config can look for your cluster. Typically it's placed on ~/.kube/config

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

Kubectl installation [instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Manifests

Deployments for [heapster](https://github.com/kubernetes/heapster), [kube-dns](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns), [kubernetes-dashboard](https://github.com/kubernetes/dashboard), [kube-router](https://kube-router.io & [metrics-server](https://github.com/kubernetes-incubator/metrics-server)

`Kube-DNS` deployment differs from the standard way as it's deployed with 3 services and 3 replicas,
then kublets is configured with 3 DNS servers in `--cluster-dns` for redundancy.

### Manually deploying addons

Use kubectl with the admin cert generated above and apply the manifests with `kubectl apply -f`

### Automated deploy of addons

This script can launch a local apiserver listening on insecure port 8080 and then use kubectl to apply the initial templates for you.

After ETCD, Masters & Workers are deployed issue:

`deploy.sh bootstrap-k8s`

## Apiserver loadbalancer & VIP

keepalived + haproxy is ran on each master node as a static pod providing a floating VIP (APISERVER_LBIP), round robin load balancing to apiservers running on all masters defined in K8S_MASTERS

keepalived peers using unicast with K8S_MASTERS