# Kubernetes for IPNett and OpenStack

This repo contains Terraform configuration files for the creation of a Kubernetes cluster.</br>
The general setup, including some of the variables, can be found [here][getting-started].

## Prerequisites

- Install [Terraform][terraform-download]
- For image-output of the dependency graph, install [Graphviz][graphviz-download]
- Network, security groups and key pair must be (pre-created) for now.
- Upload a coreos image to the openstack installation in question, place it's ID in the variables.tf file, or one of the override files
- Create security groups `ssh-uninett`, `kube-lb` and `kube-api`. Make sure there is a `default` security group (There should be)

## Good-to-know

There are three or four commands which are available for "daily usage", while the rest of Terraform's functionality and command options (as well as a more in-depth explanation of these commands) is documented [here][terraform-docs]. These commands are called on a whole folder, as Terraform loads all appropriate files from that folder. However, they are not recursive, which means that all relevant files must be located within the current directory, or referenced to by a [module][terraform-module].

1. `terraform plan`</br>
Compares your current infrastructure with the one described in the configurations files, and calculates which resources that needs to be created, recreated or deleted. This lets the developers know if everything is going to build according to plan.

2. `terraform apply`</br>
Executes the build plan and creates or destroys resources accordingly. Note that `terraform plan` does not have to be run before `terraform apply`.

3. `terraform destroy`</br>
Destroys all of your current infrastructure. If the idea is to only remove a resource, or change the number of resource instances, then it is better to write the changes to the configuration files and use `terraform apply`.

4. `terraform graph`</br>
Outputs the current infrastructure in DOT-formatted graph notation. If used with the `dot` command</br>
`terraform graph | dot -Tpng -ooutput.png`</br>
it will create a PNG-image (named 'output.png') of the current infrastructure's dependency graph.</br>
NOTE: There are **no** spaces between the flags and their arguments; this is **not** a typing error.

When changes has been made to the Terraform configurations, and `terraform apply` is called, only new or changed resources will be created, and only redundant / tainted resources will be destroyed. Even if the *apply* command fails, the created resources that *did* work will still be accessible, and will thus not be recreated (because they already exist) the next time `terraform apply` is called.

This is by design, but might lead to problems if scripts/files/settings/etc. on one resource are dependent on resources further down the dependency chain. In such cases, another command may come in handy:

- `terraform [taint|untaint] <resource>`</br>
This will mark a certain resource as *tainted*, or "unclean". A tainted resource will always be recreated on the next `terraform apply`. Use this if some resources needs to be set up again, but you don't want to level your whole infrastructure with `terraform destroy`.

## Selecting a provider

Default configuration values for various providers are in the `providers` folder. You can select which provider to use using the `-var-file` parameter to various terraform commands. Example running terraform plan towards the IPNett provider:

    terraform plan --var-file=../providers/ipnett.tfvars --var-file=../secrets/secret-credentials.tfvars

## Files and folders

As per now, there are two main folders: *secrets* and *terraform*, where the latter is where all configuration files are.

### terraform/
- **_*.tf_**</br>
Configuration files. All of Terraform's settings and resources are defined within these files. Variables should be defined in a separate file, and may be given a default value. 'Secret' variables, such as `user_name` or `password` must also be defined within these files, but may be given values by other means.

- **_*.tfvars_**</br>
Value files. Terraform variables may be given values by one of these files. Terraform will automatically load the file named *terraform.tfvars* if it's in the current directory. Otherwise if must be given as input, as such:</br>
`terraform [plan|apply|destroy] -var-file=../secrets/secret-credentials.tfvars`

- ***terraform.tfstate*** and ***terraform.tfstate.backup***</br>
Created and used by `terraform [plan|apply|destroy]` to keep track of the current infrastructure. Editing or deleting these files may (will almost certainly) cause errors, as Terraform will try to create resources that already exists.

### providers/
This folder contains default configuration values for various providers

### secrets/
This folder, must contain a set of required files before the first run.

- `ssh-key` and `ssh-key.pub`:
  A SSH keys with its associated private key.
  These will be used to access the nodes in the cluster.
  The files can be generated with: `ssh-keygen -t rsa -N '' -C 'kubernetes_key' -f ssh-key`

- `os-secrets.tfvars`:
  Contains configuration for accessing the OpenStack environment and configuration for the Kubernetes cluster.
  The file will contain something like:

  ```
  user_name = "paastest"
  password = "<SECRET>"
  cluster_name = "examplekube"
  cluster_dns_domain = "examplekube.paas2-dev.uninett.no"
  cluster_network = "00010203-0405-0607-0809-0a0b0c0d0e0f"
  ssh_key = {
    name = "examplecluster"
    private = "../secrets/ssh-key"
  }
  ```

  You must replace `example` in the text with something unique for your cluster.
  The `cluster_network` option must be replaced with a UUID for a network that you have created for the cluster.
  To create the network, you can run the following openstack commands:

  ```
  openstack --os-cloud paastest network create examplekube
  openstack --os-cloud paastest subnet create --network 00010203-0405-0607-0809-0a0b0c0d0e0f --subnet-range 10.100.0.0/24 examplekube-ipv4
  ```

  (The UUID of the cluster will be printed when running the `network create` command.)

### Uploading files to instances

Terraform comes with its own file provisioner which can take a file from the local machine and upload it to the instances created by a set resource. This works well for static files, and for any dynamic values that ends up in a file, but it can be a problem when working with *templates*. Templates can be any (text based) file where Terraform uses *interpolation variables* to insert values. When these values have been set, Terraform can access the *rendered* (finished) file, which can be used within other resources. However, the rendered template files are not saved anywhere on the local machine, and thus can't be uploaded via the file provisioner. The workaround has been to `cat` the rendered templates into the remote */tmp* folder, and from there moved to the target location.

### CoreOS' Getting Started Guide

This Terraform setup uses CoreOS' [Getting Started][getting-started] guide as one of the baselines, and is covered by the *Getting Started*, *Deploy Master Node* and *Deploy Workers* pages. *Configure kubectl* is mostly useful on the local machine, unless SSH-ing into the instances is a regular occurrence; *Deploy add-ons* only describes how to set up *one* add-on, but can be used as a reference if the addition of add-ons is needed.

## Heads up on further development

Terraform describes itself as *cloud agnostic*, which means that a developer should be able to write configurations for one type of infrastructure and make it run identically on multiple cloud platforms. This, however, does not imply that the configurations for, let's say, AWS, GCE and OpenStack will be the same, or even similar!

Even though this is a strength of Terraform (having different resources for different providers, making each provider able to fully utilize its API) this might, in some cases, make it difficult to quickly deduce if an error occurred in Terraform or came from the provider; The error messages are not always as precise as we want them.


<!-- Links and references -->
[getting-started]: https://coreos.com/kubernetes/docs/latest/getting-started.html
[terraform-download]: https://www.terraform.io/downloads.html
[terraform-docs]: https://www.terraform.io/docs/index.html
[terraform-module]: https://www.terraform.io/docs/modules/
[graphviz-download]: http://www.graphviz.org/Download..php
