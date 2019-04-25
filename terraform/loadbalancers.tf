# Load balancer for K8S API

# Internal
resource "aws_lb" "k8s-api-nlb-internal" {
  name                             = "k8s-api-elb-internal-${var.cluster_name}"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = ["${aws_subnet.main.*.id}"]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "k8s-api-nlb-internal-frontend" {
  load_balancer_arn = "${aws_lb.k8s-api-nlb-internal.arn}"
  port              = 8443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.k8s-api-nlb-internal-backend.arn}"
  }
}
resource "aws_lb_target_group" "k8s-api-nlb-internal-backend" {
  name     = "k8s-api-nlb-internal-${var.cluster_name}"
  port     = 8443
  protocol = "TCP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "k8s-api-nlb-internal-mapping" {
  count            = "${var.master_count}"
  target_group_arn = "${aws_lb_target_group.k8s-api-nlb-internal-backend.arn}"
  target_id        = "${aws_instance.master.*.id[count.index]}"
}

# External
resource "aws_lb" "k8s-api-nlb" {
  name                             = "k8s-api-elb-${var.cluster_name}"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = ["${aws_subnet.main.*.id}"]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "k8s-api-nlb-frontend" {
  load_balancer_arn = "${aws_lb.k8s-api-nlb.arn}"
  port              = 8443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.k8s-api-nlb-backend.arn}"
  }
}
resource "aws_lb_target_group" "k8s-api-nlb-backend" {
  name     = "k8s-api-nlb-${var.cluster_name}"
  port     = 8443
  protocol = "TCP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "k8s-api-nlb-mapping" {
  count            = "${var.master_count}"
  target_group_arn = "${aws_lb_target_group.k8s-api-nlb-backend.arn}"
  target_id        = "${aws_instance.master.*.id[count.index]}"
}