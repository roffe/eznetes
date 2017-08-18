#!/bin/bash
function create_bootstrap_token {
# Create TLS Bootstrap token
if [ ! -f bootstraptoken.csv ]; then
    echo "$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,\"system:kubelet-bootstrap\"" > bootstraptoken.csv
else
    echo "Bootstrap token exists"
fi
}