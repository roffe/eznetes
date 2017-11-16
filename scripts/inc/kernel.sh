#!/bin/bash

# Kernel tweaks
local TEMPLATE=/etc/modules-load.d/ipvs.conf
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack_ipv4
EOF
sudo sysctl -p ${TEMPLATE}

local TEMPLATE=/etc/sysctl.d/kubernetes.conf
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
# Increase the number of connections
net.core.somaxconn=32768

# Increase number of incoming connections backlog
net.core.netdev_max_backlog = 5000
 
# Maximum Socket Receive Buffer
net.core.rmem_max = 16777216
 
# Default Socket Send Buffer
net.core.wmem_max = 16777216
 
# Increase the maximum total buffer-space allocatable
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
 
# Increase the number of outstanding syn requests allowed
net.ipv4.tcp_max_syn_backlog = 8096
 
# For persistent HTTP connections
net.ipv4.tcp_slow_start_after_idle = 0
 
# Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
net.ipv4.tcp_tw_reuse = 1
 
# Allowed local port range
net.ipv4.ip_local_port_range = 10240 65535

# Max number of packets that can be queued on interface input
# If kernel is receiving packets faster than can be processed
# this queue increases
net.core.netdev_max_backlog = 16384

# Increase size of file handles and inode cache
fs.file-max = 2097152
EOF
sudo sysctl -p ${TEMPLATE}