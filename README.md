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

## gpfs driver

The cluster needs a gpfs file system driver. Put

    Spectrum_Scale_Advanced-4.2.2.1-x86_64-Linux-install

in `ansible/roles/gpfs/files`. Ask around for how to get it.
