PaaS 2 kubernetes platform
==========================

This repository contains scripts and ansible playbooks for managing the PaaS 2 kubernetes platform on AWS.

## Prerequisites

Need the following binaries in path
* terraform
* python3

## Troubleshooting

The bundled cfssl binary might have issues on newer OS X. Ask a friend.

## Ansible environments

Ansible is organized with environments which set up a bunch of variables for a various deploy scenarios:
* aws_eks - Use when deploying a managed EKS cluster
* aws_hosted - Use when deploying the entire cluster with Terraform/Ansible

## Bringing up a test cluster

In the `terraform` directory run `terraform init` to download the needed plugins
used by the code.

In the `terraform` directory, make a `local.tfvars` based on the
example, check your setup with `terraform plan --var-file=local.tfvars
--var-file=aws.tfvars`.

To get an AWS session using MFA run the provided script with a one time code:
```bash
./create_aws_token.sh TOKEN
```

This outputs a set of environment exports that you need to run/set.

Then, to run the complete Terraform & Ansible deploy:
```bash
./run_dev.sh -e <ansible environment name>
```
See in ansible/environments for the available environments.

To run only the terraform part:
```bash
cd terraform
terraform apply -var-file aws.tfvars -var-file local.tfvars
```

The job prints out an ansible inventory at the end, and your kubeconfig is found
at `ansible/kubeconfig`.

To destroy a test cluster, first remove the nginx-ingress service (as this has
dynamically provisioned an AWS load balancer):

```bash
kubectl -n kube-ingress delete service/nginx-ingress-lb`
```

Then, after a minute or so, destroy all resources with terraform like this:

```bash
cd terraform
terraform destroy -var-file aws.tfvars -var-file local.tfvars
```
