# NOTE: This project is no longer maintained


PaaS 2 kubernetes platform
==========================

This repository contains scripts and ansible playbooks for managing the PaaS 2 kubernetes platform.

## Bringing up a test cluster

In the `terraform` directory, make a `local.tfvars` based on the
example, check your setup with `terraform plan --var-file=local.tfvars
--var-file=ipnett.tfvars`, then bring up the bare machines with
`terraform apply --var-file=local.tfvars
--var-file=ipnett.tfvars`. The job prints out an ansible inventory at
the end.
