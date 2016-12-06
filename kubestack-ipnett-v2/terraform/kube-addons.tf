resource "null_resource" "kube-addons" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p /tmp/addons",
            "curl -o /tmp/kubectl -sSL --fail https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl",
            "chmod +x /tmp/kubectl",
        ]
    }

    provisioner "file" {
        destination = "/tmp/addons/dns-addon.yaml"
        content = "${data.template_file.dns-addon.rendered}\n"
    }

    provisioner "file" {
        destination = "/tmp/addons/heapster-addon.yaml"
        source = "${path.module}/templates/heapster-addon.yaml"
    }

    provisioner "file" {
        destination = "/tmp/addons/dashboard-addon.yaml"
        content = "${data.template_file.dashboard-addon.rendered}\n"
    }

    provisioner "file" {
        destination = "/tmp/addons/nginx-lb.yaml"
        source = "${path.module}/templates/nginx-lb.yaml"
    }

   provisioner "file" {
        destination = "/tmp/addons/kube-lego.yaml"
        source = "${path.module}/templates/kube-lego.yaml"
    }

    # Install the Kubernetes addons
    provisioner "remote-exec" {
        inline = [
            "until /tmp/kubectl get namespaces >/dev/null 2>&1; do sleep 5; done", # Wait for the API server to respond to requests.
            "/tmp/kubectl apply -f /tmp/addons",
        ]
    }

    # We connect to one of the API servers.
    connection {
        user = "core"
        host = "${openstack_compute_instance_v2.kube-apiserver.0.network.0.fixed_ip_v4}"
        private_key = "${file(var.ssh_key["private"])}"
        access_network = true
    }

    #   This resource can't be initialized until the given resources has completed.
    depends_on = [
        "null_resource.kube-apiserver",
    ]
}
