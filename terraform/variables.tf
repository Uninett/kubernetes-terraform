# From ipnett.tfvars
variable "auth_url" {}
variable "domain_name" {}
variable "tenant_name" {}
variable "region" {}
variable "node_flavor" {}
variable "worker_node_flavor" {}
variable "coreos_image" {}
variable "public_v4_network" {}

# From local.tfvars
variable "user_name" {}
variable "password" {}
variable "cluster_name" {  }
variable "cluster_dns_domain" {}

variable "allow_ssh_from_v4" {
    type = "list"
    default = []
}
variable "allow_lb_from_v4" {
    type = "list"
    default = []
}
variable "allow_api_access_from_v4" {
    type = "list"
    default = []
}

variable "ssh_public_key" { default = "~/.ssh/id_rsa.pub" }

variable "master_count" { default = 3 }
variable "worker_count" { default = 4 }

# Worker node disk size in GB
variable "worker_disk_size" { default = 25 }
