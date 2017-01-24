#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ $# -lt 3 ]; then
    echo 'Usage: generate_cert.sh CA PROFILE NAME [ALTNAMES...]' >&2
    exit 1
fi
CA="$1"; shift
PROFILE="$1"; shift
NAME="$1" # No shift here, because we are going to use $@ to get all names later

# From http://stackoverflow.com/a/17841619
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}
NAMES="$(join_by ',' $@)"

if [ ! -f "${CA}-ca.json" ]; then
    echo "Invalid CA: ${CA}" >&2
    exit 1
fi


if [ -f "${CA}/${NAME}.names" ]; then
    if [ "$(<"${CA}/${NAME}.names")" = "${NAMES}" ]; then
	echo "Certificate for ${NAME} already exists -- skipping" >&2
	exit 0
    fi
fi

if [ ! -x .cfssljson ]; then
    echo "Fetching cfssl binaries" >&2
    if [ "$(uname -sp)" = "Linux x86_64" ]; then
	variant=linux-amd64
    elif [ "$(uname -sp)" = "Darwin i386" ]; then
	variant=darwin-amd64
    else
	echo "Unknown OS variant: $(uname -sp)" >&2
	exit 1
    fi
    curl -sSL -o .cfssl "https://pkg.cfssl.org/R1.2/cfssl_${variant}"
    chmod +x .cfssl
    curl -sSL -o .cfssljson "https://pkg.cfssl.org/R1.2/cfssljson_${variant}"
    chmod +x .cfssljson
fi

if [ ! -d "${CA}" ]; then
    mkdir "${CA}"
fi

if [ ! -f "${CA}/ca.pem" ]; then
    echo "Generating CA certificate & key for ${CA}" >&2
    ./.cfssl gencert -initca "${CA}-ca.json" | ./.cfssljson -bare "${CA}/ca"
fi

# From http://stackoverflow.com/a/8088167/1954565
define(){
    IFS='\n'
    read -r -d '' ${1} || true
}

define REQUEST <<EOF
{
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "CN": "${NAME}"
}
EOF

echo "$REQUEST" | ./.cfssl gencert -ca="${CA}/ca.pem" -ca-key="${CA}/ca-key.pem" -config=ca-config.json -profile="${PROFILE}" -hostname="${NAMES}" - | ./.cfssljson -bare "${CA}/${NAME}"
echo "${NAMES}" >"${CA}/${NAME}.names"
