resource "tls_private_key" "kubernetes_ca" {
    algorithm = "ECDSA"
}

resource "tls_self_signed_cert" "kubernetes_ca" {
    key_algorithm = "${tls_private_key.kubernetes_ca.algorithm}"
    private_key_pem = "${tls_private_key.kubernetes_ca.private_key_pem}"

    subject {
        common_name = "kubernetes CA"
    }

    validity_period_hours = 175320 # About 20 years

    # CA certificate
    allowed_uses = [
        "cert_signing",
    ]
    is_ca_certificate = true
}
