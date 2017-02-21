#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f terraform/local.tfvars ]; then
    echo "You must create terraform/local.tfvars" >&2
    exit 1
fi

pushd terraform
terraform apply -var-file ipnett.tfvars -var-file local.tfvars
terraform output inventory >../ansible/inventory
popd

./ansible/apply.sh
