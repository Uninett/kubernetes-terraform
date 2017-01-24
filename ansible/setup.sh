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
