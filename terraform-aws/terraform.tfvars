### TS mandatory tags
owner      = "andre.marzulo"
keep_until = "2025-08-30"
profawscli = "tsteam"

### Your cluster configuration (Recommended use only letters on cluster name)
cluster_name        = "eksopsmanager"
region              = "eu-west-1"
vpc_cidr            = "10.42.0.0/16"
remote_network_cidr = "10.52.0.0/16"
remote_pod_cidr     = "10.53.0.0/16"

### Define your version, release and 
cluster_version     = "1.31"
ami_release_version = "1.31.7-20250620"
ami_ami_type        = "AL2023_x86_64_STANDARD"
