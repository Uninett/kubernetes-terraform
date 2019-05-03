data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Master
resource "aws_iam_role" "controlplane-instance-role" {
  name               = "K8SControlPlaneEC2Access"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}
resource "aws_iam_instance_profile" "controlplane-instance-profile" {
 name = "K8SControlPlaneEC2Access"
 role = "${aws_iam_role.controlplane-instance-role.name}"
}
resource "aws_iam_role_policy_attachment" "controlplane-instance-attach" {
  role       = "${aws_iam_role.controlplane-instance-role.name}"
  policy_arn = "${aws_iam_policy.controlplane-instance-policy.arn}"
}

# Worker
resource "aws_iam_role" "worker-instance-role" {
  name               = "K8SWorkerNodeEC2Access"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}
resource "aws_iam_instance_profile" "worker-instance-profile" {
 name = "K8SWorkerNodeEC2Access"
 role = "${aws_iam_role.worker-instance-role.name}"
}
resource "aws_iam_role_policy_attachment" "worker-instance-attach" {
  role       = "${aws_iam_role.worker-instance-role.name}"
  policy_arn = "${aws_iam_policy.worker-instance-policy.arn}"
}

# Velero backup
resource "aws_iam_user" "velero-backup-user" {
  name = "velero-backup"
}
resource "aws_iam_user_policy_attachment" "velero-backup-attach" {
  user       = "${aws_iam_user.velero-backup-user.name}"
  policy_arn = "${aws_iam_policy.velero-backup-policy.arn}"
}

# Worker policy
resource "aws_iam_policy" "worker-instance-policy" {
  name        = "K8SWorkerNodeEC2Access"
  description = "For use with instance roles that are attached to K8S worker nodes."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# Master policy
resource "aws_iam_policy" "controlplane-instance-policy" {
  name        = "K8SControlPlaneEC2Access"
  description = "For use with instance roles that are attached to K8S master nodes."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DetachVolume",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeVpcs",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancerPolicy",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DetachLoadBalancerFromSubnets",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancerPolicies",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "iam:CreateServiceLinkedRole",
                "kms:DescribeKey"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# Velero backup policy
resource "aws_iam_policy" "velero-backup-policy" {
  name        = "K8SVeleroBackupAccess"
  description = "Used by the velero IAM user and software to backup K8S resources."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::uninett-k8s-backup-mktest/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::uninett-k8s-backup-mktest"
            ]
        }
    ]
}
EOF
}