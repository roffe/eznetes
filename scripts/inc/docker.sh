#!/bin/bash

# Make sure config.json exists to prevent kubelet startup errors
mkdir -p /etc/docker
touch /etc/docker/config.json

local TEMPLATE=/etc/docker/daemon.json
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
{
    "live-restore": true
}
EOF

