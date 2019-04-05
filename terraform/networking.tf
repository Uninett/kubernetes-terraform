# Networks
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "10.2.0.0/16"

  tags {
    Name    = "${var.cluster_name}"
    project = "paas2"
  }
}

resource "aws_subnet" "main" {
  count             = "${length("${data.aws_availability_zones.available.names}")}"
  cidr_block        = "${cidrsubnet("${aws_vpc.main.cidr_block}", 8, "${count.index}")}"
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags {
    Name    = "${var.cluster_name}-${data.aws_availability_zones.available.names["${count.index}"]}"
    project = "paas2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    project = "paas2"
  }
}

resource "aws_route" "default" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Security groups
resource "aws_security_group" "ssh_access" {
  name        = "${var.cluster_name}-ssh_access"
  description = "Security group for allowing SSH access"
  vpc_id      = "${aws_vpc.main.id}"
}

resource "aws_security_group_rule" "rule_ssh_access_ipv4" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.allow_ssh_from_v4}"]
  security_group_id = "${aws_security_group.ssh_access.id}"
}

resource "aws_security_group" "api_access" {
  name        = "${var.cluster_name}-api_access"
  description = "Security group for API"
  vpc_id      = "${aws_vpc.main.id}"
}

resource "aws_security_group_rule" "api_https" {
  type              = "ingress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = "${var.allow_api_access_from_v4}"
  security_group_id = "${aws_security_group.api_access.id}"
}

resource "aws_security_group" "ingress_lb" {
  name        = "${var.cluster_name}-ingress_lb"
  description = "Security groups for web ingress load balancer"
  vpc_id      = "${aws_vpc.main.id}"
}

resource "aws_security_group_rule" "ingress_lb_http" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = "${var.allow_lb_from_v4}"
  security_group_id = "${aws_security_group.ingress_lb.id}"
}

resource "aws_security_group_rule" "allow_cluster_crosstalk" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.ssh_access.id}"
    security_group_id = "${aws_security_group.ssh_access.id}"
}