# From ipnett.tfvars
variable "auth_url" {}
variable "domain_name" {}
variable "tenant_name" {}
variable "region" {}
variable "node_flavor" {}
variable "coreos_image" {}

# From local.tfvars
variable "user_name" {}
variable "password" {}
variable "cluster_name" {  }
variable "cluster_network" {}


variable "ssh_public_key" { default = "~/.ssh/id_rsa.pub" }

variable "master_count" { default = 3 }
variable "worker_count" { default = 4 }
