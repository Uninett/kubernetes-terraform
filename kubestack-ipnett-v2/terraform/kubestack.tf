provider "openstack" {
    #   Information needed by Terraform to connect to the OpenStack Cloud.
    auth_url = "${var.auth_url}"
    user_name = "${var.user_name}"
    password = "${var.password}"
    domain_name = "${var.domain_name}"
    tenant_name = "${var.tenant_name}"
}
