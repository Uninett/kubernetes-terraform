#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f 'kubernetes-service-key.pem' ]; then
    echo 'Generates the service key used to sign service account tokens in kubernetes' >&2
    echo '{ "key": { "algo": "rsa", "size": 2048 } }' | ./bin/cfssl genkey - | ./bin/cfssljson -bare kubernetes-service
    rm kubernetes-service.csr # This file is not used.
fi
