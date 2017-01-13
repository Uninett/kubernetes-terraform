Boostrapping Ansible on the cluster
-----------------------------------

We assume that cluster already has been brought up by terraform.

## Generate node inventory

    cd ../terraform
    terraform output ansible_hosts > ../ansible/inventory
    cd -

## Install roles from community

	ansible-galaxy install -r requirements.yml

## Bootstrap ansible on nodes

    ansible-playbook -i ./inventory bootstrap.yml
