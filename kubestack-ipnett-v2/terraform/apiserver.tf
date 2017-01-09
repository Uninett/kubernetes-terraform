data "template_file" "kubelet-service" {
    count = "${var.apiserver_count}"

    template = "${file("${path.module}/templates/kubelet-apiserver.service")}"
    vars {
        k8s_ver = "${var.k8s_version}"
        network_plugin = ""
        dns_service_ip = "${var.dns_service_ip}"
        hostname_override = "${element(openstack_compute_instance_v2.kube-apiserver.*.network.0.fixed_ip_v4, count.index)}"
    }
}

data "template_file" "kube-apiserver-yaml" {
    template = "${file("${path.module}/templates/kube-apiserver.yaml")}"
    vars {
        k8s_ver = "${var.k8s_version}"
        etcd_endpoints = "${join(",", formatlist("https://%s:%s", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, var.etcd_port))}"
        service_ip_range = "${var.service_ip_range}"
    }
}

data "template_file" "kube-proxy-yaml" {
    template = "${file("${path.module}/templates/kube-proxy.yaml")}"
    vars {
        k8s_ver = "${var.k8s_version}"
    }
}

data "template_file" "kube-controller-yaml" {
    template = "${file("${path.module}/templates/kube-controller-manager.yaml")}"
    vars {
        k8s_ver = "${var.k8s_version}"
    }
}

data "template_file" "kube-scheduler-yaml" {
    template = "${file("${path.module}/templates/kube-scheduler.yaml")}"
    vars {
        k8s_ver = "${var.k8s_version}"
    }
}

data "template_file" "apiserver-kubeconfig" {
    template = "${file("${path.module}/templates/apiserver-kubeconfig.yaml")}"
    vars {
        apiserver_address = "http://127.0.0.1:8080"
        cluster_name = "${var.cluster_name}"
    }
}

data "template_file" "dns-addon" {
    template = "${file("${path.module}/templates/dns-addon.yaml")}"
    vars {
        dns_service_ip = "${var.dns_service_ip}"
    }
}

data "template_file" "dashboard-addon" {
    template = "${file("${path.module}/templates/dashboard-addon.yaml")}"
    vars {
        cluster_dns_domain = "${var.cluster_dns_domain}"
    }
}

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
        name = "kubes"
        floating_ip = "${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)}"
    }
}

resource "null_resource" "kube-apiserver" {
    count = "${var.apiserver_count}"

    # Add etcd certs & key
    provisioner "remote-exec" {
        inline = [
            "mkdir -p /tmp/etcd",
        ]
    }
    provisioner "file" {
        destination = "/tmp/etcd/ca.pem"
        content = "${tls_self_signed_cert.etcd_ca.cert_pem}"
    }
    provisioner "file" {
        destination = "/tmp/etcd/node.pem"
        content = "${element(tls_locally_signed_cert.apiserver_etcd_client.*.cert_pem, count.index)}"
    }
    provisioner "file" {
        destination = "/tmp/etcd/node-key.pem"
        content = "${element(tls_private_key.apiserver_etcd_client.*.private_key_pem, count.index)}"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo rm -rf /etc/ssl/etcd",
            "sudo chown -R root:root /tmp/etcd",
            "sudo mv /tmp/etcd /etc/ssl/",
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo chmod -R ugo+w /etc/kubernetes",
            "sudo mkdir -p /etc/flannel",
            "sudo chmod ugo+w /etc/flannel",
            "sudo mkdir -p /etc/systemd/system/flanneld.service.d",
            "sudo chmod ugo+w /etc/systemd/system/flanneld.service.d",
            "sudo mkdir -p /etc/systemd/system/docker.service.d",
            "sudo chmod ugo+w /etc/systemd/system/docker.service.d",
            "sudo chmod ugo+w /etc/systemd/system",
            "sudo mkdir /etc/kubernetes/manifests",
            "sudo chmod ugo+w /etc/kubernetes/manifests",
            "sudo mkdir -p /etc/cni/net.d",
        ]
    }

    provisioner "file" {
        destination = "/etc/kubernetes/ssl/ca.pem"
        content = "${tls_self_signed_cert.kubernetes_ca.cert_pem}"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/ssl/apiserver.pem"
        content = "${element(tls_locally_signed_cert.apiserver_kubernetes_server.*.cert_pem, count.index)}"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/ssl/apiserver-key.pem"
        content = "${element(tls_private_key.apiserver_kubernetes_server.*.private_key_pem, count.index)}"
    }

    provisioner "file" {
        destination = "/etc/flannel/options.env"
        content = "FLANNELD_IFACE=${element(openstack_compute_instance_v2.kube-apiserver.*.network.0.fixed_ip_v4, count.index)}\nFLANNELD_ETCD_ENDPOINTS=${join(",", formatlist("https://%s:%s", openstack_compute_instance_v2.etcd.*.network.0.fixed_ip_v4, var.etcd_port))}\nFLANNELD_ETCD_CAFILE=/etc/ssl/etcd/ca.pem\nFLANNELD_ETCD_CERTFILE=/etc/ssl/etcd/node.pem\nFLANNELD_ETCD_KEYFILE=/etc/ssl/etcd/node-key.pem\n"
    }

    provisioner "file" {
        destination = "/etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf"
        content = "[Service]\nExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env\n"
    }

    provisioner "file" {
        destination = "/etc/systemd/system/docker.service.d/40-flannel.conf"
        content = "[Unit]\nRequires=flanneld.service\nAfter=flanneld.service"
    }

    provisioner "file" {
        destination = "/etc/systemd/system/kubelet.service"
        content = "${element(data.template_file.kubelet-service.*.rendered, count.index)}\n"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/manifests/kube-apiserver.yaml"
        content = "${data.template_file.kube-apiserver-yaml.rendered}\n"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/manifests/kube-proxy.yaml"
        content = "${data.template_file.kube-proxy-yaml.rendered}"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/manifests/kube-controller-manager.yaml"
        content = "${data.template_file.kube-controller-yaml.rendered}\n"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/manifests/kube-scheduler.yaml"
        content = "${data.template_file.kube-scheduler-yaml.rendered}\n"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/apiserver-kubeconfig.yaml"
        content = "${data.template_file.apiserver-kubeconfig.rendered}"
    }

    provisioner "file" {
        destination = "/etc/kubernetes/service-key.pem"
        content = "${tls_private_key.apiserver_service_account.private_key_pem}"
    }

    #   Transfer keys and config files to the api-server
    provisioner "remote-exec" {
        inline = [
            "sudo chmod 600 /etc/kubernetes/ssl/*-key.pem",
            "sudo chown root:root /etc/kubernetes/ssl/*-key.pem",
            "sudo chmod 600 /etc/kubernetes/service-key.pem",
            "sudo chown root:root /etc/kubernetes/service-key.pem",

            "sudo systemctl daemon-reload",
            "sudo systemctl start docker",
            "sudo systemctl enable docker",
            "sudo systemctl start kubelet",
            "sudo systemctl enable kubelet",
        ]
    }

    # Configure locksmithd for coordinated reboot of the nodes.
    provisioner "file" {
        destination = "/tmp/locksmithd.conf"
        content = "${data.template_file.locksmithd.rendered}"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/systemd/system/locksmithd.service.d",
            "sudo chown -R root:root /tmp/locksmithd.conf",
            "sudo mv /tmp/locksmithd.conf /etc/systemd/system/locksmithd.service.d/",
            "sudo systemctl daemon-reload",
            "sudo systemctl restart locksmithd",
        ]
    }

    #   Tells Terraform how to connect to instances of this type.
    #   The floating ip is the same one given to 'network'.
    #   'file(...)' loads the private key, and gives it to Terraform for secure connection.
    connection {
        user = "core"
        host = "${element(openstack_compute_floatingip_v2.api_flip.*.address, count.index)}"
        private_key = "${file(var.ssh_key["private"])}"
        access_network = true
    }

    #   This resource can't be initialized until the given resources has completed.
    depends_on = [
        "null_resource.etcd",
        "null_resource.flannel_config",
    ]
}

resource "openstack_compute_floatingip_v2" "api_flip" {
    #   Get one floating ip for the api server
    count = "${var.apiserver_count}"

    region = "${var.region}"
    pool = "public-v4"
}
