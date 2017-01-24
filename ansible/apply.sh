#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

./setup.sh

ANSIBLE_HOST_KEY_CHECKING=false .ve/bin/ansible-playbook --become --inventory=inventory site.yaml

