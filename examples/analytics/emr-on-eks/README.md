# EMR on EKS on an existing EKS cluster
This module is for adding emr on eks stuff on top of an existing eks cluster.
Please update "eks_cluster_id" in variables.tf


# Deploy 
cd /<path to repo>/examples/analytics/emr-on-eks
region=<your region> #set region
terraform init 
terraform apply -var region=$region --auto-approve #defaults to us-west-2

# Output
Outputs:

emr_on_eks_role_arn = [
  "arn:aws:iam::349361870252:role/managed-airflow-mwaa-emr-eks-data-team-a",
  "arn:aws:iam::349361870252:role/managed-airflow-mwaa-emr-eks-data-team-b",
]
emrcontainers_virtual_cluster_id = "k6lnbify6k461x88ng3akdlgu"



# test
cd examples/spark-execute
./basic-pyspark-job.sh "<virtual-cluster-id>" "arn:aws:iam::xxxxxx:role/managed-airflow-mwaa-emr-eks-data-team-a"

  aws emr-containers start-job-run --virtual-cluster-id <virtual-cluster-id> --name test --execution-role-arn arn:aws:iam::xxxxxx:role/managed-airflow-mwaa-emr-eks-data-team-a \
    --release-label emr-6.5.0-latest \
    --job-driver '{
      "sparkSubmitJobDriver": {
        "entryPoint": "local:///usr/lib/spark/examples/src/main/python/pi.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=2 --conf spark.executor.memory=2G --conf spark.executor.cores=2 --conf spark.driver.cores=1"
      }
    }'
    