#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -x ./.ve/bin/ansible ]; then
    echo "Setting up Python virtualenv containing ansible."
    rm -rf .ve
    python3 -m venv .ve
    .ve/bin/pip install --upgrade pip
    .ve/bin/pip install ansible
    .ve/bin/pip install markupsafe
fi

if [ ! -x ./tls/bin/cfssl -o ! -x ./tls/bin/cfssljson ]; then
    echo "Fetching cfssl binaries" >&2
    mkdir -p "./tls/bin"
    if [ "$(uname -sm)" = "Linux x86_64" ]; then
	variant=linux-amd64
    elif [ "$(uname -sm)" = "Darwin x86_64" ]; then
	variant=darwin-amd64
    else
	echo "Unknown OS variant: $(uname -sp)" >&2
	exit 1
    fi
    curl -sSL -o "./tls/bin/cfssl" "https://pkg.cfssl.org/R1.2/cfssl_${variant}"
    chmod +x "./tls/bin/cfssl"
    curl -sSL -o "./tls/bin/cfssljson" "https://pkg.cfssl.org/R1.2/cfssljson_${variant}"
    chmod +x "./tls/bin/cfssljson"
fi

./tls/init_cas.sh
