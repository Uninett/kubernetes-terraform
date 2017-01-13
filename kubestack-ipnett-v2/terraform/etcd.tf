resource "openstack_compute_floatingip_v2" "etcd_flip" {
    #   Pull x floating ips from the given ip-pool, where x is the number of etcd instances.
    count = "${var.etcd_count}"

    region = "${var.region}"
    pool = "public-v4"
}

resource "openstack_compute_servergroup_v2" "etcd_servers" {
    name = "${var.cluster_name}-etcd-servers"
    policies = ["anti-affinity"]
    region = "${var.region}"
}

resource "openstack_compute_instance_v2" "etcd" {
    #   Creating 'count' number of etcd instances.
    count = "${var.etcd_count}"

    name = "${var.cluster_name}-etcd-${count.index}"
    region = "${var.region}"
    image_id = "${var.images["coreos"]}"
    flavor_name = "${var.etcd_flavor}"
    key_pair = "${openstack_compute_keypair_v2.keypair.name}"
    security_groups = [
        "default",
        "ssh-uninett"
    ]

    scheduler_hints {
        group = "${openstack_compute_servergroup_v2.etcd_servers.id}"
    }

    #   Connecting to the set network with the provided floating ip.
    network {
        uuid = "${var.cluster_network}"
        floating_ip = "${element(openstack_compute_floatingip_v2.etcd_flip.*.address, count.index)}"
    }
}

resource "tls_private_key" "etcd_ca" {
    algorithm = "RSA"
}

resource "tls_self_signed_cert" "etcd_ca" {
    key_algorithm = "${tls_private_key.etcd_ca.algorithm}"
    private_key_pem = "${tls_private_key.etcd_ca.private_key_pem}"

    subject {
        common_name = "etcd CA"
    }

    validity_period_hours = 175320 # About 20 years

    # CA certificate
    allowed_uses = [
        "cert_signing",
    ]
    is_ca_certificate = true
}

resource "tls_private_key" "etcd" {
    count = "${var.etcd_count}"
    algorithm = "RSA"
}

resource "tls_cert_request" "etcd" {
    count = "${var.etcd_count}"
    key_algorithm = "${element(tls_private_key.etcd.*.algorithm, count.index)}"
    private_key_pem = "${element(tls_private_key.etcd.*.private_key_pem, count.index)}"

    subject {
        common_name = "${element(openstack_compute_instance_v2.etcd.*.name, count.index)}"
    }
    ip_addresses = [
        "${element(openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, count.index)}"
    ]
}

resource "tls_locally_signed_cert" "etcd" {
    count = "${var.etcd_count}"
    cert_request_pem = "${element(tls_cert_request.etcd.*.cert_request_pem, count.index)}"

    ca_key_algorithm = "${tls_private_key.etcd_ca.algorithm}"
    ca_private_key_pem = "${tls_private_key.etcd_ca.private_key_pem}"
    ca_cert_pem = "${tls_self_signed_cert.etcd_ca.cert_pem}"

    validity_period_hours = 175320 # About 20 years

    allowed_uses = [
        "digital_signature",
        "key_encipherment",
        "server_auth",
        "client_auth",
    ]
}

data "template_file" "etcd" {
    #   Loads a file from the given folder, inserts values where variables are specified, and returnes a complete, rendered file.
    #   'count' makes sure that the correct number of rendered templates are being created, as 'flip' must be different for each etcd instance.
    count = "${var.etcd_count}"

    template = "${file("${path.module}/templates/etcd2.conf")}"
    vars {
        name = "${element(openstack_compute_instance_v2.etcd.*.name, count.index)}"
        initial_advertise_peer_urls = "https://${element(openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, count.index)}:2380"
        advertise_client_urls = "${join(",", formatlist("https://%s:2379", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4))}"
        initial_cluster = "${join(",", formatlist("%s=https://%s:2380", openstack_compute_instance_v2.etcd.*.name, openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4))}"
    }
}

resource "null_resource" "etcd" {
    #   Creating 'count' number of etcd instances.
    count = "${var.etcd_count}"

    provisioner "local-exec" {
        command = "mkdir -p  ../etcd"
    }

    provisioner "local-exec" {
        command = <<EOC
tee ../etcd/ca.pem <<EOF
${tls_self_signed_cert.etcd_ca.cert_pem}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../etcd/${var.cluster_name}-etcd-${count.index}.pem <<EOF
${element(tls_locally_signed_cert.etcd.*.cert_pem, count.index)}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../etcd/${var.cluster_name}-etcd-${count.index}-key.pem <<EOF
${element(tls_private_key.etcd.*.private_key_pem, count.index)}
EOF
EOC
    }

    #   Creating a configuration file for etcd based on the given template.
    #   Give the config-file to etcd, reload and start up.
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir /etc/systemd/system/etcd2.service.d",
            "cat << 'EOF' > /tmp/etcd2.conf\n${element(data.template_file.etcd.*.rendered, count.index)}\nEOF",
            "sudo mv /tmp/etcd2.conf /etc/systemd/system/etcd2.service.d/",
            "sudo systemctl daemon-reload",
            "sudo systemctl enable etcd2",
            "sudo systemctl start etcd2"
        ]
    }

    #   Tells Terraform how to connect to instances of this type.
    #   The floating ip is the same one given to 'network'.
    #   'file(...)' loads the private key, and gives it to Terraform for secure connection.
    connection {
        user = "core"
        host = "${element(openstack_compute_floatingip_v2.etcd_flip.*.address, count.index)}"
        private_key = "${file(var.ssh_key["private"])}"
        access_network = true
    }
}
