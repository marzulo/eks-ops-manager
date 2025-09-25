# eks-ops-manager
Deploy Ops Manager and MongoDB using MCK 1.4.0 on AWS EKS with Terraform

==__THIS IS A WORKING IN PROGRESS - Do not recommended to use without speak with owner__==

## Steps to install:

### Step 1: Pre requisites

- MANA: 10gen-aws-tsteam-member-iam-plus
- AWS CLI installed with SSO login configured (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#cli-configure-sso-configure):
    you must have the configuration to login to aws using `aws sso login --profile <your profile configured>`
- kubectl: https://kubernetes.io/docs/tasks/tools/
- eksctl: https://eksctl.io/installation/
- terraform configured to support your aws cli configuration: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create
- GNU-based commands for `sed` and `base64``
    - If you are on MacOS computer install then by typing:
      ```brew install gnu-sed coreutils```
      Update your PATH to to have `coreutils` and `gnu-sed` with priority


### Step 2. Prepare execution
Go to **terraform-aws** dir and configure the _terraform.tfvars_ with the following information of your deployment:

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

### Step 3. Create the infrastructure
With the _terraform.tfvars_ file prepared, initialize and validate your Terraform setup:
- ```terraform init```
- ```terraform plan```

If the plan runs without errors, proceed with:
- ```terraform apply```

This step provisions the EKS cluster and supporting AWS infrastructure.
Checking AWS Console
Navigate to the AWS Console and verify on each service:
- EKS and navigate into the Cluster called <cluster_name>;
- EFS and check a File System called efs_<cluster_name>
- VPC and check a VPC called efs_<cluster_name>
- S3 and check a bucket named <cluster_name>-logs-<RandomString>

### Step 4. Create the MongoDB Operator environment
Once the infrastructure is deployed, navigate to the **mongodb-kubernetes** directory.
Run the script script_deploy_om.sh to deploy the MongoDB Kubernetes Operator and Ops Manager:

```./script_deploy_om.sh <AWS_REGION> <EKS_CLUSTER_NAME> <PROFILE>```

These parameters you should take from the _terraform.tfvars_ that you configured in the step 2 as follow:
< AWS_REGION > = region
< EKS_CLUSTER_NAME > = cluster_name
< PROFILE > = profawscli

_(At this stage, the script execution should be done manually. Ensure you verify outputs and logs before continuing.)_

After completing this step, you can verify the environment by accessing the **Ops Manager UI**, **Mailpit UI**, and checking the deployment status using kubectl. Follow the instructions below:

To retrieve the **Mailpit URL**, run the following command:

```echo "Mailpit Web UI URL: http://`kubectl get svc mailpit-svc-ext -n mailpit -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`:8025"```

To retrieve the **Ops Manager URL**, use the following command::

```echo "Ops Manager UI URL: https://`kubectl get svc ops-manager-svc-ext -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`:8443"```

If you see a _“Secure Connection Failed”_ message, please wait a bit longer. The Load Balancer may take up to 2 minutes to become publicly accessible.

If you encounter a _“Warning: Potential Security Risk Ahead”_
 message, click “Advanced” and then “Accept the Risk and Continue”. This message appears because a Custom CA certificate is being used for the HTTPS connection.

You can log in to Ops Manager using the following credentials:
Username: _a@b.com_
Password: _Password123!_

### Step 5. Deploy a sharded cluster with backup enabled after finish the deployment

If you wish you can apply the MongoDB sharded cluster configuration with backup enabled:

```kubectl apply -f mongodb-sharded-creation.yaml```

This step deploys a **MongoDB** sharded cluster on your **EKS** cluster, with backups configured according to the YAML definition.

You can connect to the Sharded cluster through the mongos pod using the following command:

```bash
shardurl="mongodb://backupuser:mongod123XMONGOD123x@`kubectl get svc mongodb-sharded-mongos-0-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`:27017/"
mongosh $shardurl
```

### Step 6. Deploy Search Node

Finally, you can apply the MongoDB Search Node with a Replica Set using MongoDB Enterprise FCV 8.2:

```./script_deploy_om.sh <AWS_REGION> <EKS_CLUSTER_NAME> <PROFILE>```

These parameters you should take from the terraform.tfvars that you configured in the step 2 as follow:
< AWS_REGION > = region
< EKS_CLUSTER_NAME > = cluster_name
< PROFILE > = profawscli

_(At this stage, the script execution should be done manually. Ensure you verify outputs and logs before continuing.)_

You can connect to the Replica Set with Search node enabled using the following commands:
```bash
lbsvcurl0=`kubectl get svc rssearch-0-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
lbsvcurl1=`kubectl get svc rssearch-1-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
lbsvcurl2=`kubectl get svc rssearch-2-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
mongoshurl="mongodb://rssearch-admin:mongod123XMONGOD123x@$lbsvcurl0:27017,$lbsvcurl1:27017,$lbsvcurl2:27017/?tls=true&tlsCAFile=tls/test-CA.pem&tlsCertificateKeyFile=tls/test-rsbackup.pem&tlsAllowInvalidCertificates=true&replicaSet=rssearch"
mongosh $mongoshurl
```


7. Playing with Search Nodes (Optional)

You can load sample data into the newly created **Replica Set** and create a new index using the commands below. Once the index is in place, you can proceed with testing the **Vector Index** feature by following the official documentation:

```bash
echo "Downloading sample data locally"
curl -Ol https://atlas-education.s3.amazonaws.com/sample_mflix.archive
echo "Restoring sample database"
mongorestore  --archive=sample_mflix.archive  --verbose=1  --drop  --nsInclude 'sample_mflix.*'  --uri="$mongoshurl"
echo "Creating vector index"
mongosh --quiet "$mongoshurl" --eval "use sample_mflix" \
    --eval 'db.embedded_movies.createSearchIndex("vector_index", "vectorSearch",
    { "fields": [ {
      "type": "vector",
      "path": "plot_embedding_voyage_3_large",
      "numDimensions": 2048,
      "similarity":
      "dotProduct",
      "quantization": "scalar"
    } ] });'
sleep 60
echo "Verifying vector index creation"
mongosh --quiet "$mongoshurl" --eval "use sample_mflix" --eval 'db.runCommand({"listSearchIndexes": "embedded_movies"});'
```

After completing these steps, please refer to the [documentation here](https://www.mongodb.com/docs/kubernetes/current/tutorial/fts-vs-quickstart/#query-the-data-using-the-index.) to begin working with the index you created.

### Conclusion

By following these steps, you will:
- Provision **AWS** infrastructure for **EKS** using **Terraform**.
- Deploy **MongoDB Ops Manager** with **X509** authentication on AppDB, **TLS enabled** communication for the UI using the **MCK Operator**.
- Launch a fully functional **MongoDB sharded cluster** with **backup enabled** with **SCRAM authentication**.
- Deploy a **Vector Search** lab using a publicly accessible **Replica Set**.

### 8. Destroying environment

Before proceeding with the deletion of your **AWS infrastructure**, it’s important to clean up the **Kubernetes** elements deployed on **EKS**, particularly the **LoadBalancer services** created for **MongoDB** and **Mailpit**. These **services** are managed by EKS cluster but **are external** and were not provisioned by Terraform, which means they may not be automatically removed. Failing to delete them properly can result in AWS resources remaining active, potentially leading to errors or unnecessary costs.

You have two cleanup scripts available:

**To delete only the Search Lab (Replica Set and Search Pod):**

```./script_destroy_search.sh```

**To delete the entire environment (excluding the Operator):**

```./script_destroy_all.sh```

**Final Step: Delete AWS Infrastructure**

Once all EKS-related components have been removed, you can proceed to delete the AWS infrastructure by navigating to the **terraform-aws** directory and run the following command:

```terraform destroy --auto-approve```

After execution completes, verify that no errors occurred.
Also, go to the **AWS Console** and navigate to the **VPC** service. Confirm that the VPC created for this environment no longer exists. **If the VPC is still present**, check for any remaining resources (e.g., Elastic IPs, Load Balancers, Gateways) that might require manual deletion to fully clean up your environment. 

### Next steps
- Implement multiple EKS Node Groups with both ARM and x86 architectures, and configure appropriate Pod Affinity and Anti-Affinity rules for workload distribution.
- Prepare script_deploy and script_destroy scripts to support local deployments using Docker and KinD (Kubernetes in Docker).
- Configure MongoDB Kubernetes Operator (MCK) in Static Mode with container images hosted on Amazon ECR to reduce data transfer costs.
- Set up a multi-cluster environment using Cilium for advanced networking and policy control.
- Develop a lab scenario to integrate a Search Node (with TLS enabled) with a Replica Set deployed on EC2 instances in a separate VPC.

