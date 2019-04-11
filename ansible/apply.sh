#!/bin/bash
set -e
set -o pipefail

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

cd "$(dirname "${BASH_SOURCE[0]}")"

ANSIBLE_ENV_DIR="environments/${ANSIBLE_ENV}"

if [ ! -d "${ANSIBLE_ENV_DIR}" ]; then
    echo "The Ansible environment you specificed doesn't seem to exist, please create it at: ${ANSIBLE_ENV_DIR}" >&2
    exit 1
fi

./setup.sh

.ve/bin/ansible-playbook site.yaml -i "${ANSIBLE_ENV_DIR}"
