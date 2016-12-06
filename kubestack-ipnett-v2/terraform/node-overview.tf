output "nodes" {
    value = <<EOF
###
# etcd nodes
${join("\n", formatlist("%s %s", openstack_compute_instance_v2.etcd.*.name, openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4))}
# api servers
${join("\n", formatlist("%s %s", openstack_compute_instance_v2.kube-apiserver.*.name, openstack_compute_instance_v2.kube-apiserver.*.network.0.fixed_ip_v4))}
# workers
${join("\n", formatlist("%s %s", openstack_compute_instance_v2.kube.*.name, openstack_compute_instance_v2.kube.*.network.0.fixed_ip_v4))}
EOF
}
