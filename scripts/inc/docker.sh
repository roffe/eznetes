#!/bin/bash
local TEMPLATE=/etc/docker/daemon.json
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
{
    "live-restore": true
}
EOF

