#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() { echo "Usage: $0 -e <ANSIBLE_ENVIRONMENT>"; exit 0; }

while getopts e: option
do
    case "${option}" in
	e)
	    ANSIBLE_ENV=${OPTARG}
	    ;;
	*)
            usage
            ;;
    esac
done
shift "$((OPTIND-1))"

if [ -z "${ANSIBLE_ENV}" ] ; then
    usage
fi

ANSIBLE_ENV_DIR="ansible/environments/${ANSIBLE_ENV}"

if [ ! -d "${ANSIBLE_ENV_DIR}" ]; then
    echo "The Ansible environment you specificed doesn't seem to exist, please create it at: ${ANSIBLE_ENV_DIR}" >&2
    exit 1
fi

if [ ! -f terraform/local.tfvars ]; then
    echo "You must create terraform/local.tfvars" >&2
    exit 1
fi

pushd terraform

terraform apply -var-file aws.tfvars -var-file local.tfvars
terraform output inventory >"../${ANSIBLE_ENV_DIR}"/hosts

popd

./ansible/apply.sh -e "${ANSIBLE_ENV}"
