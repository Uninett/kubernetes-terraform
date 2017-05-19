#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f terraform/local.tfvars ]; then
    echo "You must create terraform/local.tfvars" >&2
    exit 1
fi

pushd terraform
# This first (serial) run of the security group rules are needed due to strange
# behaviour where only some of the rules are there after the initial run unless
# the are processed sequentially.
#
# See:
#     https://github.com/hashicorp/terraform/issues/7519
#
terraform apply -var-file ipnett.tfvars -var-file local.tfvars -parallelism 1 \
          -target openstack_networking_secgroup_rule_v2.rule_ssh_access_ipv4 \
          -target openstack_networking_secgroup_rule_v2.rule_kube_lb_http_ipv4 \
          -target openstack_networking_secgroup_rule_v2.rule_kube_lb_https_ipv4 \
          -target openstack_networking_secgroup_rule_v2.rule_kube_master_ipv4

# Now, do the rest in parallell as normal
terraform apply -var-file ipnett.tfvars -var-file local.tfvars
terraform output inventory >../ansible/inventory
popd

./ansible/apply.sh
