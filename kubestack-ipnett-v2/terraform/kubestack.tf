provider "openstack" {
    #   Information needed by Terraform to connect to the OpenStack Cloud.
    auth_url = "${var.auth_url}"
    user_name = "${var.user_name}"
    password = "${var.password}"
    domain_name = "${var.domain_name}"
    tenant_name = "${var.tenant_name}"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.ssh_key["name"]}"
  region = "${var.region}"
  public_key = "${file(var.ssh_key["public"])}"
}
