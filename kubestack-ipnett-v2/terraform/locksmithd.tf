data "template_file" "locksmithd" {
    template = "${file("${path.module}/templates/locksmithd.conf")}"
    vars {
        endpoint = "${join(",", formatlist("https://%s:2379", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4))}"
    }
}
