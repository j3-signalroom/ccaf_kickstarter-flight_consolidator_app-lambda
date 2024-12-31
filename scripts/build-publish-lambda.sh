#!/bin/bash

#
# *** Script Syntax ***
# scripts/build-publish-lambda.sh <create | delete> --profile=<SSO_PROFILE_NAME>
#
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
    echo "Usage:  Require all four arguments ---> `basename $0` <create | delete> --profile=<SSO_PROFILE_NAME>"
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
else
    # Force the delete of the ECR Repository
    aws ecr delete-repository --repository-name ${repo_name} ${AWS_PROFILE} --force || true
fi