data "template_file" "masters_ansible" {
    template = "$${name} $${extra}"
    count = "${var.apiserver_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.kube-apiserver.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)}"
    }
}

data "template_file" "etcd_ansible" {
    template = "$${name} $${extra}"
    count = "${var.etcd_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.etcd.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.etcd_flip.*.address, count.index)}"
    }
}

data "template_file" "workers_ansible" {
    template = "$${name} $${extra}"
    count = "${var.worker_count}"
    vars {
        name  = "${element(openstack_compute_instance_v2.kube.*.name, count.index)}"
        extra = "ansible_host=${element(openstack_compute_floatingip_v2.kube_flip.*.address, count.index)} lb=${count.index < var.lb_count ? "true" : "false"}"
    }
}

data "template_file" "ansible_hosts" {
    template = "${file("${path.module}/templates/ansible-hosts.tpl")}"
    vars {
        master_hosts = "${join("\n",data.template_file.masters_ansible.*.rendered)}"
        etcd_hosts = "${join("\n",data.template_file.etcd_ansible.*.rendered)}"
        worker_hosts = "${join("\n",data.template_file.workers_ansible.*.rendered)}"
        ssh_key = "${var.ssh_key["private"]}"
        cluster_name  = "${var.cluster_name}"
        cluster_dns_domain = "${var.cluster_dns_domain}"
        dns_service_ip = "${var.dns_service_ip}"
        k8s_ver = "${var.k8s_version}"
        k8s_ver_kubelet = "${var.k8s_version_kubelet}"
        network_plugin = "cni"
        service_ip_range = "${var.service_ip_range}"
        etcd_endpoints = "${join(",", formatlist("https://%s:%s", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, var.etcd_port))}"
        etcd_initial_cluster = "${join(",", formatlist("%s=https://%s:2380", openstack_compute_instance_v2.etcd.*.name, openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4))}"
    }
}

output "ansible_hosts" {
    value = "${data.template_file.ansible_hosts.rendered}"
}

resource "null_resource" "ansible_inventory" {
    provisioner "local-exec" {
        command = "echo '${data.template_file.ansible_hosts.rendered}' > ../ansible/inventory"
    }
}
