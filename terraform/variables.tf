# From aws.tfvars
variable "aws_region" {}
variable "aws_role" {}

variable "master_instance_type" {}
variable "worker_instance_type" {}
variable "image" {}

# From local.tfvars
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

# Master node disk size in GB
variable "master_disk_size" { default = 25 }
# Worker node disk size in GB
variable "worker_disk_size" { default = 25 }
