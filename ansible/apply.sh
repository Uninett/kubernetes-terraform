#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

./setup.sh

.ve/bin/ansible-playbook --become --inventory=inventory site.yaml

