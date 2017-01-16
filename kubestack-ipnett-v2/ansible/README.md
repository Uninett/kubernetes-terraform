Boostrapping Ansible on the cluster
-----------------------------------

We assume that cluster already has been brought up by terraform. Terraform will write a inventory file when bringing up cluster

## Install roles from community

	ansible-galaxy install -r requirements.yml

## Bootstrap ansible on nodes

    ansible-playbook -i ./inventory bootstrap.yml
