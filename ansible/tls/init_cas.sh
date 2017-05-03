#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

for FILE in *-ca.json; do
    CA="${FILE%%-ca.json}"
    if [ ! -d "${CA}" ]; then
	mkdir -p "${CA}"
	echo "Generating CA certificate & key for ${CA}" >&2
	./bin/cfssl gencert -initca "${FILE}" | ./bin/cfssljson -bare "${CA}/ca"
    fi
done
