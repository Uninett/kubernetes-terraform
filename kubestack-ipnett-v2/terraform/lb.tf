data "template_file" "etcdctl_cmd" {
    template = "${file("${path.module}/templates/etcdctl_cmd")}"

    count = "${var.lb_count}"
    vars {
        index = "${count.index}"
        cluster_name = "${var.cluster_name}"
        address = "${element(openstack_compute_floatingip_v2.kube_flip.*.address,count.index)}"
    }
}

output "lb-config" {
    value = <<EOF
###
# Commands to set the load balancer backend addresses for this cluster
${join("", data.template_file.etcdctl_cmd.*.rendered)}
EOF
}
