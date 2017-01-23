#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -x ./.ve/bin/ansible ]; then
    # Install ansible in virtualenv
    rm -rf .ve
    virtualenv -p python2 .ve
    .ve/bin/pip install ansible
fi

ANSIBLE_HOST_KEY_CHECKING=false .ve/bin/ansible-playbook --become --inventory=inventory site.yaml

