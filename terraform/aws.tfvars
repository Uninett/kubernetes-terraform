aws_region = "eu-north-1"
# TODO: Parameter needed for later prod
aws_role = "arn:aws:iam::295267165045:role/EC2AccessFromTerraform"

# AWS Instance types
# ...
master_instance_type = "m5.xlarge"
worker_instance_type = "m5.xlarge"

# TODO: Lookup this in the main.tf instead, ref:
# https://letslearndevops.com/2018/08/23/terraform-get-latest-centos-ami/
# https://www.terraform.io/docs/providers/aws/d/ami_ids.html
image = "ami-3c0a8342" # EU (Stockholm) ami CoreOS
