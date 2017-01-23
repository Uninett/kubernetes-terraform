provider "openstack" {
    auth_url = "${var.auth_url}"
    domain_name = "${var.domain_name}"
    tenant_name = "${var.tenant_name}"
    user_name = "${var.user_name}"
    password = "${var.password}"
}

# SSH Key
resource "openstack_compute_keypair_v2" "keypair" {
    name = "${var.cluster_name}"
    region = "${var.region}"
    public_key = "${file(var.ssh_public_key)}"
}

# Master nodes
resource "openstack_compute_floatingip_v2" "master" {
    count = "${var.master_count}"
    region = "${var.region}"
    pool = "public-v4"
}
resource "openstack_compute_instance_v2" "master" {
    count = "${var.master_count}"
    name = "${var.cluster_name}-master-${count.index}"
    region = "${var.region}"
    image_id = "${var.centos_image}"
    flavor_name = "${var.node_flavor}"
    key_pair = "${openstack_compute_keypair_v2.keypair.name}"
    security_groups = [
        "default",
        "ssh-uninett",
        "kube-api",
    ]

    #   Connecting to the set network with the provided floating ip.
    network {
        uuid = "${var.cluster_network}"
        floating_ip = "${element(openstack_compute_floatingip_v2.master.*.address, count.index)}"
    }
}


# Worker nodes
resource "openstack_compute_floatingip_v2" "worker" {
    count = "${var.worker_count}"
    region = "${var.region}"
    pool = "public-v4"
}
resource "openstack_compute_instance_v2" "worker" {
    count = "${var.worker_count}"
    name = "${var.cluster_name}-worker-${count.index}"
    region = "${var.region}"
    image_id = "${var.centos_image}"
    flavor_name = "${var.node_flavor}"
    key_pair = "${openstack_compute_keypair_v2.keypair.name}"
    security_groups = [
        "default",
        "ssh-uninett",
        "kube-lb",
    ]

    #   Connecting to the set network with the provided floating ip.
    network {
        uuid = "${var.cluster_network}"
        floating_ip = "${element(openstack_compute_floatingip_v2.worker.*.address, count.index)}"
    }
}


data "template_file" "masters_ansible" {
    template = "$${name} ansible_host=$${ip}"
    count = "${var.master_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.master.*.name, count.index)}"
        ip = "${element(openstack_compute_floatingip_v2.master.*.address, count.index)}"
    }
}

data "template_file" "workers_ansible" {
    template = "$${name} ansible_host=$${ip}"
    count = "${var.worker_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.worker.*.name, count.index)}"
        ip = "${element(openstack_compute_floatingip_v2.worker.*.address, count.index)}"
    }
}

data "template_file" "inventory_tail" {
    template = "$${section_children}\n$${section_vars}"
    vars = {
        section_children = "[servers:children]\nmasters\nworkers"
        section_vars = "[servers:vars]\nansible_ssh_user=centos"
    }
}

data "template_file" "inventory" {
    template = "\n[masters]\n$${master_hosts}\n[workers]\n$${worker_hosts}\n$${inventory_tail}"
    vars {
        master_hosts = "${join("\n",data.template_file.masters_ansible.*.rendered)}"
        worker_hosts = "${join("\n",data.template_file.workers_ansible.*.rendered)}"
        inventory_tail = "${data.template_file.inventory_tail.rendered}"
    }
}

output "inventory" {
    value = "${data.template_file.inventory.rendered}"
}
