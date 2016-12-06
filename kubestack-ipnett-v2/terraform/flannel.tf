data "template_file" "flannel-command" {
    template = "${file("${path.module}/templates/flannel-command")}"
    vars {
        pod_network = "${var.pod_network}"
        etcd_endpoints = "${join(",", formatlist("https://%s:%s", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, var.etcd_port))}"
    }
}

resource "null_resource" "flannel_config" {
    provisioner "remote-exec" {
        inline = [
            "${data.template_file.flannel-command.rendered}",
        ]
    }

    connection {
        user = "core"
        host = "${openstack_compute_instance_v2.etcd.0.network.0.fixed_ip_v4}"
        private_key = "${file(var.ssh_key["private"])}"
        access_network = true
    }

    # Apply after etcd is configured
    depends_on = ["null_resource.etcd"]
}
