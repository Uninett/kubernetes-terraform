resource "tls_private_key" "kube_etcd_client" {
    count = "${var.worker_count}"
    algorithm = "RSA"
}

resource "tls_cert_request" "kube_etcd_client" {
    count = "${var.worker_count}"
    key_algorithm = "${element(tls_private_key.kube_etcd_client.*.algorithm, count.index)}"
    private_key_pem = "${element(tls_private_key.kube_etcd_client.*.private_key_pem, count.index)}"

    subject {
        common_name = "${var.cluster_name}-kube-${count.index}"
    }
}

resource "tls_locally_signed_cert" "kube_etcd_client" {
    count = "${var.worker_count}"
    cert_request_pem = "${element(tls_cert_request.kube_etcd_client.*.cert_request_pem, count.index)}"

    ca_key_algorithm = "${tls_private_key.etcd_ca.algorithm}"
    ca_private_key_pem = "${tls_private_key.etcd_ca.private_key_pem}"
    ca_cert_pem = "${tls_self_signed_cert.etcd_ca.cert_pem}"

    validity_period_hours = 175320 # About 20 years

    allowed_uses = [
        "digital_signature",
        "key_encipherment",
        "client_auth",
    ]
}

resource "tls_private_key" "kube_apiserver_client" {
    count = "${var.worker_count}"
    algorithm = "RSA"
}

resource "tls_cert_request" "kube_apiserver_client" {
    count = "${var.worker_count}"
    key_algorithm = "${element(tls_private_key.kube_apiserver_client.*.algorithm, count.index)}"
    private_key_pem = "${element(tls_private_key.kube_apiserver_client.*.private_key_pem, count.index)}"

    subject {
        common_name = "kube-worker-${count.index}"
        organization = "worker"
    }
}

resource "tls_locally_signed_cert" "kube_apiserver_client" {
    count = "${var.worker_count}"
    cert_request_pem = "${element(tls_cert_request.kube_apiserver_client.*.cert_request_pem, count.index)}"

    ca_key_algorithm = "${tls_private_key.kubernetes_ca.algorithm}"
    ca_private_key_pem = "${tls_private_key.kubernetes_ca.private_key_pem}"
    ca_cert_pem = "${tls_self_signed_cert.kubernetes_ca.cert_pem}"

    validity_period_hours = 175320 # About 20 years

    allowed_uses = [
        "digital_signature",
        "key_encipherment",
        "client_auth",
    ]
}

resource "openstack_compute_servergroup_v2" "workers" {
    name = "${var.cluster_name}-workers"
    policies = ["anti-affinity"]
    region = "${var.region}"
}

data "template_file" "lb_sec_group" {
    template = "${join(",", var.lb_sec_groups)}"
    count = "${var.lb_count}"
}

data "template_file" "worker_sec_group" {
    template = "${join(",", var.worker_sec_groups)}"
    count = "${var.worker_count - var.lb_count}"
}

resource "openstack_compute_instance_v2" "kube" {
    #   Create as many worker instances as needed
    count = "${var.worker_count}"

    name = "${var.cluster_name}-kube-${count.index}"
    region = "${var.region}"
    image_id = "${var.images["coreos"]}"
    flavor_name = "${var.worker_flavor}"
    key_pair = "${openstack_compute_keypair_v2.keypair.name}"
    security_groups = ["${split(",",element(concat(data.template_file.lb_sec_group.*.rendered, data.template_file.worker_sec_group.*.rendered), count.index))}"]

    scheduler_hints {
        group = "${openstack_compute_servergroup_v2.workers.id}"
    }

    #   Connecting to the set network with the provided floating ip.
    network {
        uuid = "${var.cluster_network}"
        floating_ip = "${element(openstack_compute_floatingip_v2.kube_flip.*.address, count.index)}"
    }

}

resource "null_resource" "kube" {
    count = "${var.worker_count}"

    # Add etcd certs & key
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
tee ../etcd/${var.cluster_name}-kube-${count.index}.pem <<EOF
${element(tls_locally_signed_cert.kube_etcd_client.*.cert_pem, count.index)}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../etcd/${var.cluster_name}-kube-${count.index}-key.pem <<EOF
${element(tls_private_key.kube_etcd_client.*.private_key_pem, count.index)}
EOF
EOC
    }

    provisioner "local-exec" {
        command = <<EOC
tee ../kubernetes/${var.cluster_name}-kube-${count.index}.pem <<EOF
${element(tls_locally_signed_cert.kube_apiserver_client.*.cert_pem, count.index)}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../kubernetes/${var.cluster_name}-kube-${count.index}-key.pem <<EOF
${element(tls_private_key.kube_apiserver_client.*.private_key_pem, count.index)}
EOF
EOC
    }

}

resource "openstack_compute_floatingip_v2" "kube_flip" {
    #   Pull y floating ips from the given ip-pool, where y is the number of worker instances.
    count = "${var.worker_count}"

    region = "${var.region}"
    pool = "public-v4"
}
