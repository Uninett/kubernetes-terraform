# This ugly hack for tag name interpolation inspired by:
# https://blog.scottlowe.org/2018/06/11/using-variables-in-aws-tags-with-terraform/

locals {
    common_tags = "${map(
        "kubernetes.io/cluster/${var.cluster_name}", "uninett",
        "project", "paas2"
    )}"
}

# Configure the AWS Provider
provider "aws" {
  region = "${var.aws_region}"

  assume_role {
    role_arn     = "${var.aws_role}"
    session_name = "${var.cluster_name}-terraform-run" # TODO: What should be the id here?
  }
}

data "aws_ami" "latest-ubuntu" {
most_recent = true
owners = ["099720109477"] # Canonical
  filter {
      name   = "name"
      values = ["ubuntu-minimal/images/hvm-ssd/ubuntu-bionic-18.04-amd64-minimal-*"]
  }

  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.cluster_name}"
  public_key = "${file(var.ssh_public_key)}"
}

# Master nodes
resource "aws_instance" "master" {
  count                  = "${var.master_count}"
  ami                    = "${data.aws_ami.latest-ubuntu.id}"
  instance_type          = "${var.master_instance_type}"
  key_name               = "${aws_key_pair.keypair.key_name}"
  subnet_id              = "${element(aws_subnet.main.*.id, count.index % length(aws_subnet.main.*.id))}"
  vpc_security_group_ids = ["${aws_vpc.main.default_security_group_id}", "${aws_security_group.ssh_access.id}", "${aws_security_group.api_access.id}"] # TODO: Is the default group needed/wanted here?
  user_data              = "#cloud-config\npreserve_hostname: true\n"
  source_dest_check      = false
  iam_instance_profile   = "${var.aws_master_iam_profile}"

  root_block_device {
    delete_on_termination = true
    volume_size           = "${var.master_disk_size}"
  }

  tags = "${merge(
    local.common_tags,
    map(
        "Name", "${var.cluster_name}-master-${count.index}",
        "k8s-role", "master"
    )
  )}"

  lifecycle {
    ignore_changes = [
      # Ignore changes to ami
      "ami",
    ]
  }
}

resource "aws_eip" "master" {
  count    = "${var.master_count}"
  instance = "${aws_instance.master.*.id[count.index]}"
}

data "template_file" "masters_ansible" {
  template = "$${name} internal_ip=$${internal_ip} ansible_host=$${ip} public_ip=$${ip}"
  count    = "${var.master_count}"

  vars {
    name        = "${element(aws_instance.master.*.private_dns, count.index)}"
    ip          = "${aws_eip.master.*.public_ip[count.index]}"
    internal_ip = "${element(aws_instance.master.*.private_ip, count.index)}"
  }
}

# Worker nodes
resource "aws_instance" "worker" {
  count                  = "${var.worker_count}"
  ami                    = "${data.aws_ami.latest-ubuntu.id}"
  instance_type          = "${var.worker_instance_type}"
  key_name               = "${aws_key_pair.keypair.key_name}"
  subnet_id              = "${element(aws_subnet.main.*.id, count.index % length(aws_subnet.main.*.id))}"
  vpc_security_group_ids = ["${aws_vpc.main.default_security_group_id}", "${aws_security_group.ssh_access.id}", "${aws_security_group.ingress_lb.id}"]
  user_data              = "#cloud-config\npreserve_hostname: true\n"
  source_dest_check      = false
  iam_instance_profile   = "${var.aws_worker_iam_profile}"

  root_block_device {
    delete_on_termination = true
    volume_size           = "${var.worker_disk_size}"
  }

  tags = "${merge(
    local.common_tags,
    map(
        "Name", "${var.cluster_name}-worker-${count.index}",
        "k8s-role", "worker"
    )
  )}"

  lifecycle {
    ignore_changes = [
      # Ignore changes to ami
      "ami",
    ]
  }

}

resource "aws_eip" "worker" {
  count    = "${var.worker_count}"
  instance = "${aws_instance.worker.*.id[count.index]}"
}

data "template_file" "workers_ansible" {
  template = "$${name} internal_ip=$${internal_ip} ansible_host=$${ip} public_ip=$${ip}"
  count    = "${var.worker_count}"

  vars {
    name        = "${element(aws_instance.worker.*.private_dns, count.index)}"
    ip          = "${aws_eip.worker.*.public_ip[count.index]}"
    internal_ip = "${element(aws_instance.worker.*.private_ip, count.index)}"
  }
}

# S3 bucket for backups
resource "aws_s3_bucket" "backup" {
  bucket = "uninett-k8s-backup-${var.cluster_name}"
  acl    = "private"

  tags = {
    Name        = "k8s-backup-${var.cluster_name}"
  }
}

data "template_file" "inventory_tail" {
  template = "$${section_children}\n$${section_vars}"

  vars = {
    section_children = "[servers:children]\nmasters\nworkers"
    section_vars     = "[servers:vars]\nansible_become=yes\nansible_ssh_user=ubuntu\nansible_python_interpreter=python3\n[all:children]\nservers\n[all:vars]\ncluster_name=${var.cluster_name}\ncluster_dns_domain=${var.cluster_dns_domain}\napi_internal_lb_name=${aws_lb.k8s-api-nlb-internal.dns_name}\napi_external_lb_name=${aws_lb.k8s-api-nlb.dns_name}"
  }
}

data "template_file" "inventory" {
  template = "\n[masters]\n$${master_hosts}\n[workers]\n$${worker_hosts}\n$${inventory_tail}"

  vars {
    master_hosts   = "${join("\n",data.template_file.masters_ansible.*.rendered)}"
    worker_hosts   = "${join("\n",data.template_file.workers_ansible.*.rendered)}"
    inventory_tail = "${data.template_file.inventory_tail.rendered}"
  }
}

output "inventory" {
  value = "${data.template_file.inventory.rendered}"
}

output "backup-bucket" {
  value = "${aws_s3_bucket.backup.arn}"
}
