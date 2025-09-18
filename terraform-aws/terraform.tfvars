### TS mandatory tags
owner      = "name.surname"
keep_until = "2026-01-01"
profawscli = "team"

### Your cluster configuration (Recommended use only letters on cluster name)
cluster_name        = "yourclustername"
region              = "eu-west-1"
vpc_cidr            = "10.??.0.0/16"
remote_network_cidr = "10.??.0.0/16"
remote_pod_cidr     = "10.??.0.0/16"

### Define your version, release and 
cluster_version     = "1.33"
ami_release_version = "1.33.4-20250904"
ami_ami_type        = "AL2023_x86_64_STANDARD"
