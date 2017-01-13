
resource "tls_private_key" "apiserver_etcd_client" {
    count = "${var.apiserver_count}"
    algorithm = "RSA"
}

resource "tls_cert_request" "apiserver_etcd_client" {
    count = "${var.apiserver_count}"
    key_algorithm = "${element(tls_private_key.apiserver_etcd_client.*.algorithm, count.index)}"
    private_key_pem = "${element(tls_private_key.apiserver_etcd_client.*.private_key_pem, count.index)}"

    subject {
        common_name = "${var.cluster_name}-apiserver-${count.index}"
    }
}

resource "tls_locally_signed_cert" "apiserver_etcd_client" {
    count = "${var.apiserver_count}"
    cert_request_pem = "${element(tls_cert_request.apiserver_etcd_client.*.cert_request_pem, count.index)}"

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

resource "tls_private_key" "apiserver_kubernetes_server" {
    count = "${var.apiserver_count}"
    algorithm = "RSA"
}

resource "tls_cert_request" "apiserver_kubernetes_server" {
    count = "${var.apiserver_count}"
    key_algorithm = "${element(tls_private_key.apiserver_kubernetes_server.*.algorithm, count.index)}"
    private_key_pem = "${element(tls_private_key.apiserver_kubernetes_server.*.private_key_pem, count.index)}"

    subject {
        common_name = "${var.cluster_dns_domain}"
    }
    dns_names = [
        "${var.cluster_dns_domain}",
        "kubernetes",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster.local",
    ]
    ip_addresses = [
        "127.0.0.1", # To access via haproxy running on localhost
        "${var.k8s_service_ip}",
        "${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)}",
        "${element(openstack_compute_instance_v2.kube-apiserver.*.network.0.fixed_ip_v4, count.index)}",
    ]
}

resource "tls_locally_signed_cert" "apiserver_kubernetes_server" {
    count = "${var.apiserver_count}"
    cert_request_pem = "${element(tls_cert_request.apiserver_kubernetes_server.*.cert_request_pem, count.index)}"

    ca_key_algorithm = "${tls_private_key.kubernetes_ca.algorithm}"
    ca_private_key_pem = "${tls_private_key.kubernetes_ca.private_key_pem}"
    ca_cert_pem = "${tls_self_signed_cert.kubernetes_ca.cert_pem}"

    validity_period_hours = 175320 # About 20 years

    allowed_uses = [
        "digital_signature",
        "key_encipherment",
        "server_auth",
    ]
}

resource "tls_private_key" "apiserver_service_account" {
    algorithm = "RSA"
}

resource "openstack_compute_servergroup_v2" "apiservers" {
    name = "${var.cluster_name}-apiservers"
    policies = ["anti-affinity"]
    region = "${var.region}"
}

resource "openstack_compute_instance_v2" "kube-apiserver" {
    count = "${var.apiserver_count}"
    #   This instances may also be called 'master'.
    #   Only one instance of this type is supposed to be active at any time.
    name = "${var.cluster_name}-apiserver-${count.index}"
    region = "${var.region}"
    image_id = "${var.images["coreos"]}"
    flavor_name = "${var.apiserver_flavor}"
    key_pair = "${openstack_compute_keypair_v2.keypair.name}"
    security_groups = [
        "default",
        "ssh-uninett",
        "kube-api",
    ]

    scheduler_hints {
        group = "${openstack_compute_servergroup_v2.apiservers.id}"
    }

    #   Connecting to the set network with the provided floating ip.
    network {
        uuid = "${var.cluster_network}"
        floating_ip = "${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)}"
    }
}

resource "null_resource" "kube-apiserver" {
    count = "${var.apiserver_count}"

    # Add etcd certs & key
    provisioner "local-exec" {
        command = "mkdir -p  ../etcd"
    }
    provisioner "local-exec" {
        command = "mkdir -p  ../masters/kubernetes"
    }
    provisioner "local-exec" {
        command = "mkdir -p  ../masters/service_account"
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
tee ../etcd/${var.cluster_name}-apiserver-${count.index}.pem <<EOF
${element(tls_locally_signed_cert.apiserver_etcd_client.*.cert_pem, count.index)}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../etcd/${var.cluster_name}-apiserver-${count.index}-key.pem <<EOF
${element(tls_private_key.apiserver_etcd_client.*.private_key_pem, count.index)}
EOF
EOC
    }

    provisioner "local-exec" {
        command = <<EOC
tee ../masters/kubernetes/ca.pem <<EOF
${tls_self_signed_cert.kubernetes_ca.cert_pem}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../masters/kubernetes/${var.cluster_name}-apiserver-${count.index}.pem <<EOF
${element(tls_locally_signed_cert.apiserver_kubernetes_server.*.cert_pem, count.index)}
EOF
EOC
    }
    provisioner "local-exec" {
        command = <<EOC
tee ../masters/kubernetes/${var.cluster_name}-apiserver-${count.index}-key.pem <<EOF
${element(tls_private_key.apiserver_kubernetes_server.*.private_key_pem, count.index)}
EOF
EOC
    }

    provisioner "local-exec" {
        command = <<EOC
tee ../masters/service_account/${var.cluster_name}-apiserver-${count.index}.pem <<EOF
${tls_private_key.apiserver_service_account.private_key_pem}
EOF
EOC
    }

    #   This resource can't be initialized until the given resources has completed.
    depends_on = [
        "null_resource.etcd",
    ]
}

resource "openstack_compute_floatingip_v2" "api_flip" {
    #   Get one floating ip for the api server
    count = "${var.apiserver_count}"

    region = "${var.region}"
    pool = "public-v4"
}
