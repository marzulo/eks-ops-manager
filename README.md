# eks-ops-manager
Deploy Ops Manager and MongoDB using MCK 1.4.0 on AWS EKS with Terraform

=__THIS IS A WORKING IN PROGRESS - Do not recommended to use without speak with owner__=

## Steps to install:

### Step 1: Pre requisites

- MANA: 10gen-aws-tsteam-member-iam-plus
- AWS CLI installed with SSO login configured (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#cli-configure-sso-configure):
    you must have the configuration to login to aws using `aws sso login --profile <your profile configured>`
- kubectl: https://kubernetes.io/docs/tasks/tools/
- eksctl: https://eksctl.io/installation/
- terraform configured to support your aws cli configuration: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create

### Step 2. Prepare execution
Go to terraform-aws dir and configure the terraform.tfvars with the following information of your deployment:

```
### TS mandatory tags
owner      = "name.surname"
keep_until = "YYYY-MM-DD"
profawscli = "your_aws_cli_profile_name"

### Your cluster configuration (Recommended use only letters on cluster name)
cluster_name        = "clustername"
region              = "eu-west-1"
vpc_cidr            = "10.??.0.0/16"
remote_network_cidr = "10.??.0.0/16"
remote_pod_cidr     = "10.??.0.0/16"

### Define your version, release and 
cluster_version     = "1.33"
ami_release_version = "1.33.4-20250904"
ami_ami_type        = "AL2023_x86_64_STANDARD"
```

### Step 3. Create the infra
After terraform.vars configured type:
- ```terraform init```
- ```terraform plan```

If no error so far:
- ```terraform apply```

### Step 4. Create the MongoDB Operator environment
Go to mongodb-kubernetes, and execute the script: 

```./script_deploy_om.sh <AWS_REGION> <EKS_CLUSTER_NAME> <PROFILE>``` 

> (I suggest to run the commands manually to understand each step and follow the rollout)

_(**TODO**) Improve rsbackup deployment rollout_

### Step 5. Deploy a sharded cluster with backup enabled after finish the deployment

```kubectl apply -f mongodb-sharded-creation.yaml```

_(**TODO**) Step 6. Spin up Vector Search pod._


## Steps to destroy:

### Step 1. Cleanup MongoDB elements
Go to mongodb-kubernetes, and execute the script:
```./script_destroy_om.sh```

> If the command get stucked whille cleaning up the `pvc` you can shoot the command below in another window:

```kubectl patch pvc  head-ops-manager-backup-daemon-0 -p '{"metadata":{"finalizers":null}}' --type=merge```

### Step 2. Cleanup AWS Infrastructure
Go to terraform-aws dir and type:
- ```terraform destroy --auto-approve```
