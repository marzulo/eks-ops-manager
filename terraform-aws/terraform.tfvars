### TS mandatory tags
owner      = "andre.marzulo"
keep_until = "2027-01-01"
profawscli = "aws_cli_profile"

### Your cluster configuration (Recommended use only letters on cluster name)
cluster_name        = "clustername"
region              = "eu-central-1"
vpc_cidr            = "10.0.0.0/16"
remote_network_cidr = "10.13.0.0/16"
remote_pod_cidr     = "10.14.0.0/16"

### Define your version, release and 
cluster_version     = "1.36"
ami_release_version = "1.36.2-20260625"
ami_ami_type_x86    = "AL2023_x86_64_STANDARD"
ami_ami_type_arm    = "AL2023_ARM_64_STANDARD"
ami_ami_type_nvidia = "AL2023_x86_64_NVIDIA"
