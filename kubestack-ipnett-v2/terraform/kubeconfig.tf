resource "tls_private_key" "kube_admin" {
    algorithm = "ECDSA"
}

resource "tls_cert_request" "kube_admin" {
    key_algorithm = "${tls_private_key.kube_admin.algorithm}"
    private_key_pem = "${tls_private_key.kube_admin.private_key_pem}"

    subject {
        common_name = "kube-admin"
    }
}

resource "tls_locally_signed_cert" "kube_admin" {
    cert_request_pem = "${tls_cert_request.kube_admin.cert_request_pem}"

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

output "kubectl-config" {
    value = <<EOF
###
# Commands to configure cluster for kubectl
kubectl config set-cluster '${var.cluster_name}' --server 'https://${openstack_compute_floatingip_v2.api_flip.0.address}/'
kubectl config set 'clusters.${var.cluster_name}.certificate-authority-data' '${base64encode(tls_self_signed_cert.kubernetes_ca.cert_pem)}'
kubectl config set 'users.${var.cluster_name}-admin.client-certificate-data' '${base64encode(tls_locally_signed_cert.kube_admin.cert_pem)}'
kubectl config set 'users.${var.cluster_name}-admin.client-key-data' '${base64encode(tls_private_key.kube_admin.private_key_pem)}'
kubectl config set-context '${var.cluster_name}-admin' --cluster '${var.cluster_name}' --user ${var.cluster_name}-admin
kubectl config use-context '${var.cluster_name}-admin'
EOF
}
