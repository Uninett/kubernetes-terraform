#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

CERT="$1"

if [ -z "$CERT" ]
then
    echo "Must pass certificate name" >&2
    exit 1
fi

echo '{ "key": { "algo": "rsa", "size": 2048 } }' | ./bin/cfssl genkey - | ./bin/cfssljson -bare "${CERT}"
rm "${CERT}.csr" # This file is not used.
