# Update these values according to your setup
aws_region                = "ap-south-1"
environment               = "observability-challenge"
vpc_cidr                  = "10.0.0.0/16"
public_subnet_cidr        = "10.0.1.0/24"
jenkins_instance_type     = "c7i-flex.large"
monitoring_instance_type  = "c7i-flex.large"

# IMPORTANT: Create an EC2 key pair first and update this
key_name = "jenkins-observability-key"

# AMI IDs for Ubuntu 22.04 LTS - update based on your region
# us-east-1: ami-0c7217cdde317cfec
# us-west-2: ami-0735c191cf914754d
jenkins_ami   = "ami-02b8269d5e85954ef"
monitoring_ami = "ami-02b8269d5e85954ef"

