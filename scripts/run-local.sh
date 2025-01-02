#!/bin/bash

#
# *** Script Syntax ***
# scripts/run-local.sh <create | delete> --profile=<SSO_PROFILE_NAME>
#                                        --catalog-name=<CATALOG_NAME>
#                                        --database-name=<DATABASE_NAME>
#                                        --ccaf-secrets-path=<CCAF_SECRETS_PATH>
#

# Check required command (create or delete) was supplied
case $1 in
  create)
    create_action=true;;
  delete)
    create_action=false;;
  *)
    echo
    echo "(Error Message 001)  You did not specify one of the commands: create | delete."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0` <create | delete> --profile=<SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
    ;;
esac

# Get the arguments passed by shift to remove the first word
# then iterate over the rest of the arguments
shift
for arg in "$@" # $@ sees arguments as separate words
do
    case $arg in
        *"--profile="*)
            AWS_PROFILE=$arg;;
        *"--catalog-name="*)
            arg_length=15
            CATALOG_NAME=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-name="*)
            arg_length=16
            DATABASE_NAME=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--ccaf-secrets-path="*)
            arg_length=20
            CCAF_SECRETS_PATH=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
    esac
done

# Check required --profile argument was supplied
if [ -z $AWS_PROFILE ]
then
    echo
    echo "(Error Message 002)  You did not include the proper use of the --profile=<SSO_PROFILE_NAME> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --catalog-name argument was supplied
if [ -z $CATALOG_NAME ] && [ create_action = true ]
then
    echo
    echo "(Error Message 003)  You did not include the proper use of the --catalog-name=<CATALOG_NAME> argument in the call."
    echo
    echo "Usage:  Require ---> `basename $0` --profile=<AWS_SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-name argument was supplied
if [ -z $DATABASE_NAME ] && [ create_action = true ]
then
    echo
    echo "(Error Message 004)  You did not include the proper use of the --database-name=<DATABASE_NAME> argument in the call."
    echo
    echo "Usage:  Require ---> `basename $0` --profile=<AWS_SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-name argument was supplied
if [ -z $CCAF_SECRETS_PATH ]
then
    echo
    echo "(Error Message 005)  You did not include the proper use of the --ccaf-secrets-path=<CCAF_SECRETS_PATH> argument in the call."
    echo
    echo "Usage:  Require ---> `basename $0` --profile=<AWS_SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Set the AWS environment credential variables that are used
# by the AWS CLI commands to authenicate
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get sso_region $AWS_PROFILE)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Function to handle the repo exist error
repo_exist_handler() {
    aws ecr delete-repository --repository-name ${repo_name} ${AWS_PROFILE} --force
}

# Set the trap to catch repo exist error
trap 'repo_exist_handler' ERR

# Define the ECR Repository name and URL variables
repo_name="ccaf_kickstarter-flight_consolidator_app"
repo_url="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo_name}"

# Execute the create or delete action
if [ "$create_action" = true ]
then
    # Force the delete of the ECR Repository (if it exists)
    aws ecr delete-repository --repository-name ${repo_name} ${AWS_PROFILE} --force || true

    # Create the ECR Repository
    aws ecr create-repository --repository-name ${repo_name} ${AWS_PROFILE} || true

    # Get the Docker login password and login to the ECR Repository
    aws ecr get-login-password --region ${AWS_REGION} ${AWS_PROFILE} | docker login --username AWS --password-stdin ${repo_url}

    # Build the Docker image and push the Docker image to the ECR Repository
    docker build --no-cache --platform linux/amd64 -t ${repo_name} .
    docker tag ${repo_name}:latest ${repo_url}:latest
    docker push ${repo_url}:latest

    # Create terraform.tfvars file
    printf "aws_account_id=\"${AWS_ACCOUNT_ID}\"\
    \naws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nccaf_secrets_path=\"${CCAF_SECRETS_PATH}\"\
    \ncatalog_name=\"${CATALOG_NAME}\"\
    \ndatabase_name=\"${DATABASE_NAME}\"" > terraform.tfvars

    # Initialize the Terraform configuration
    terraform init

    # Create/Update the Terraform configuration
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars
else
    # Create terraform.tfvars file
    printf "aws_account_id=\"${AWS_ACCOUNT_ID}\"\
    \naws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nccaf_secrets_path=\"${CCAF_SECRETS_PATH}\"" > terraform.tfvars
    
    # Initialize the Terraform configuration
    terraform init

     # Destroy the Terraform configuration
    terraform destroy -var-file=terraform.tfvars

    # Force the delete of the ECR Repository
    aws ecr delete-repository --repository-name ${repo_name} ${AWS_PROFILE} --force || true
fi