aws_region = "eu-north-1"
aws_master_iam_profile = "K8SControlPlaneEC2Access"
aws_worker_iam_profile = "K8SWorkerNodeEC2Access"

# AWS VPC Defaults
aws_vpc_cidr_block = "10.2.0.0/16"

# AWS Instance types
# ...
master_instance_type = "m5.xlarge"
worker_instance_type = "m5.xlarge"
