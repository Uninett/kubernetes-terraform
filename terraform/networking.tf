# Networks

resource "openstack_networking_network_v2" "network_1" {
  name = "${var.cluster_name}"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name = "${var.cluster_name}_subnet"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr = "10.2.0.0/24"
  ip_version = 4
}

resource "openstack_networking_router_v2" "router_1" {
  name = "${var.cluster_name}_router"
  external_gateway = "${var.public_v4_network}"
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.router_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}


# Security groups

resource "openstack_networking_secgroup_v2" "grp_ssh_access" {
    region = "${var.region}"
    name = "${var.cluster_name}-ssh_access"
    description = "Security groups for allowing SSH access"
}

resource "openstack_networking_secgroup_rule_v2" "rule_ssh_access_ipv4" {
    count = "${length(var.allow_ssh_from_v4)}"
    region = "${var.region}"
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 22
    port_range_max = 22
    remote_ip_prefix = "${element(var.allow_ssh_from_v4, count.index)}"
    security_group_id = "${openstack_networking_secgroup_v2.grp_ssh_access.id}"
}

resource "openstack_networking_secgroup_v2" "grp_kube_lb" {
    region = "${var.region}"
    name = "${var.cluster_name}-kube_lb"
    description = "Security groups for allowing web access to lb nodes"
}

resource "openstack_networking_secgroup_rule_v2" "rule_kube_lb_http_ipv4" {
    count = "${length(var.allow_lb_from_v4)}"
    region = "${var.region}"
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 80
    port_range_max = 80
    remote_ip_prefix = "${element(var.allow_lb_from_v4, count.index)}"
    security_group_id = "${openstack_networking_secgroup_v2.grp_kube_lb.id}"
}

resource "openstack_networking_secgroup_rule_v2" "rule_kube_lb_https_ipv4" {
    count = "${length(var.allow_lb_from_v4)}"
    region = "${var.region}"
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 443
    port_range_max = 443
    remote_ip_prefix = "${element(var.allow_lb_from_v4, count.index)}"
    security_group_id = "${openstack_networking_secgroup_v2.grp_kube_lb.id}"
}

resource "openstack_networking_secgroup_v2" "grp_kube_master" {
    region = "${var.region}"
    name = "${var.cluster_name}_kube_master"
    description = "Security groups for allowing API access to the master nodes"
}

resource "openstack_networking_secgroup_rule_v2" "rule_kube_master_ipv4" {
    count = "${length(var.allow_api_access_from_v4)}"
    region = "${var.region}"
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 8443
    port_range_max = 8443
    remote_ip_prefix = "${element(var.allow_api_access_from_v4, count.index)}"
    security_group_id = "${openstack_networking_secgroup_v2.grp_kube_master.id}"
}

