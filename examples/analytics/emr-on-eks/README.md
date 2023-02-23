# EMR on EKS on an existing EKS cluster



./basic-pyspark-job.sh "k6lnbify6k461x88ng3akdlgu" "arn:aws:iam::349361870252:role/managed-airflow-mwaa-emr-eks-data-team-a"

  aws emr-containers start-job-run --virtual-cluster-id k6lnbify6k461x88ng3akdlgu --name test --execution-role-arn arn:aws:iam::349361870252:role/managed-airflow-mwaa-emr-eks-data-team-a \
    --release-label emr-6.5.0-latest \
    --job-driver '{
      "sparkSubmitJobDriver": {
        "entryPoint": "local:///usr/lib/spark/examples/src/main/python/pi.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=2 --conf spark.executor.memory=2G --conf spark.executor.cores=2 --conf spark.driver.cores=1"
      }
    }'
    
    
Karpenter provisioners component is commented out for now because of the error