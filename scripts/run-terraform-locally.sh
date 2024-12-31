#!/bin/bash

#
# *** Script Syntax ***
# scripts/run-terraform-locally.sh <create | delete> --profile=<SSO_PROFILE_NAME> \
#                                                    --catalog-name=<CATALOG_NAME> \
#                                                    --database-name=<DATABASE_NAME> \
#                                                    --ccaf-secrets-path=<CCAF_SECRETS_PATH>
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
    echo "Usage:  Require all four arguments ---> `basename $0` <create | delete> --profile=<AWS_SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
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

# Retrieve from the AWS SSO account information to set the SSO AWS_ACCESS_KEY_ID, 
# AWS_ACCESS_SECRET_KEY, AWS_SESSION_TOKEN, AWS_REGION, and AWS_ACCOUNT_ID
# environmental variables
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get sso_region $AWS_PROFILE)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity $AWS_PROFILE --query "Account" --output text)

# Create terraform.tfvars file
if [ "$create_action" = true ]
then
    printf "aws_account_id=\"${AWS_ACCOUNT_ID}\"\
    \naws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nccaf_secrets_path=\"${CCAF_SECRETS_PATH}\"\
    \ncatalog_name=\"${CATALOG_NAME}\"\
    \ndatabase_name=\"${DATABASE_NAME}\"" > terraform.tfvars
else
    printf "aws_account_id=\"${AWS_ACCOUNT_ID}\"\
    \naws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nccaf_secrets_path=\"${CCAF_SECRETS_PATH}\"" > terraform.tfvars
fi

# Initialize the Terraform configuration
terraform init

if [ "$create_action" = true ]
then
    # Create/Update the Terraform configuration
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars
else
    # Destroy the Terraform configuration
    terraform destroy -var-file=terraform.tfvars
fi
