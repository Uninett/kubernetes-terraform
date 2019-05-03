PaaS 2 kubernetes platform
==========================

This repository contains scripts and ansible playbooks for managing the PaaS 2 kubernetes platform on AWS.

## Prerequisites

Need the following binaries in path
* terraform
* virtualenv

## Troubleshooting

The bundled cfssl binary might have issues on OS X. Ask a friend.

## Ansible environments

Ansible is organized with environments which set up a bunch of variables for a various deploy scenarios:
* aws_eks - Use when deploying a managed EKS cluster
* aws_hosted - Use when deploying the entire cluster with Terraform/Ansible

## Bringing up a test cluster

In the `terraform` directory, make a `local.tfvars` based on the
example, check your setup with `terraform plan --var-file=local.tfvars
--var-file=ipnett.tfvars`.

To run the complete Terraform & Ansible deploy:
```bash
./run_dev.sh -e <ansible environment name>
```
See in ansible/environments for the available environments.

To run only the terraform part:
```bash
terraform apply -var-file aws.tfvars -var-file local.tfvars
```
The job prints out an ansible inventory at the end.
