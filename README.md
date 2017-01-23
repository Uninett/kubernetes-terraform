NIRD-SP kubernetes platform
===========================

This repository contains scripts and ansible playbooks for managing the NIRD-SP kubernetes platform.

## Bringing up a test cluster

In the `terraform` directory, make a `local.tfvars` based on the
example, check your setup with `terraform plan --var-file=local.tfvars
--var-file=ipnett.tfvars`, then bring up the bare machines with
`terraform apply --var-file=local.tfvars
--var-file=ipnett.tfvars`. The job prints out an ansible inventory at
the end.

## Running ansible

The first time you run ansible on the new cluser, set the env variable
`ANSIBLE_HOST_KEY_CHECKING` to `False`. Otherwise, ansible gets stuck
on unknown host keys.
