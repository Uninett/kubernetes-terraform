data "template_file" "masters_ansible" {
    template = "$${name} $${extra}"
    count = "${var.apiserver_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.kube-apiserver.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)} ansible_ssh_private_key_file=${var.ssh_key["private"]} ansible_become=true"
    }
}

data "template_file" "etcd_ansible" {
    template = "$${name} $${extra}"
    count = "${var.etcd_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.etcd.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.etcd_flip.*.address, count.index)} ansible_ssh_private_key_file=${var.ssh_key["private"]} ansible_become=true"
    }
}

data "template_file" "workers_ansible" {
    template = "$${name} $${extra}"
    count = "${var.worker_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.kube.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.kube_flip.*.address, count.index)} ansible_ssh_private_key_file=${var.ssh_key["private"]} ansible_become=true lb=${count.index < var.lb_count ? "true" : "false"}"
    }
}

data "template_file" "ansible_hosts" {
    template = "${file("${path.module}/templates/ansible-hosts.tpl")}"
    vars {
        master_hosts = "${join("\n",data.template_file.masters_ansible.*.rendered)}"
        etcd_hosts = "${join("\n",data.template_file.etcd_ansible.*.rendered)}"
        worker_hosts = "${join("\n",data.template_file.workers_ansible.*.rendered)}"
    }
}

output "ansible_hosts" {
    value = "${data.template_file.ansible_hosts.rendered}"
}
