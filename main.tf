terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "ccaf-kickstarter-flight-consolidator-app"
        }
  }

  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.95.0"
        }
    }
}

locals {
    # Repo name and URIs
    repo_name    = "ccaf_kickstarter-flight_consolidator_app"
    repo_uri     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.repo_name}:latest"
    ecr_repo_uri = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.repo_name}"
}
