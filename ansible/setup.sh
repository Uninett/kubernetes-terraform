#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -x ./.ve/bin/ansible ]; then
    echo "Setting up Python virtualenv containing ansible."
    rm -rf .ve
    virtualenv -p python2 .ve
    .ve/bin/pip install ansible
fi

if [ ! -x ./tls/bin/cfssl -o ! -x ./tls/bin/cfssljson ]; then
    echo "Fetching cfssl binaries" >&2
    mkdir -p "./tls/bin"
    if [ "$(uname -sp)" = "Linux x86_64" ]; then
	variant=linux-amd64
    elif [ "$(uname -sp)" = "Darwin i386" ]; then
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
./tls/init_kubernetes_service_key.sh

gpfs_installer="Spectrum_Scale_Advanced-4.2.2.1-x86_64-Linux-install"
gpfs_dir="roles/gpfs/files"
if [ ! -f $gpfs_dir/$gpfs_installer ]
then
    echo "$gpfs_installer not found in $gpfs_dir"
    exit 1
fi
