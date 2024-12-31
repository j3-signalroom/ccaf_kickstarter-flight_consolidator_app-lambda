variable "aws_region" {
    description = "The AWS Region."
    type        = string
}

variable "aws_account_id" {
    description = "The AWS Account ID."
    type        = string
}

variable "aws_access_key_id" {
    description = "The AWS Access Key ID."
    type        = string
    default     = ""
}

variable "aws_secret_access_key" {
    description = "The AWS Secret Access Key."
    type        = string
    default     = ""
}

variable "aws_session_token" {
    description = "The AWS Session Token."
    type        = string
    default     = ""
}

variable "catalog_name" {
    description = "The CCAF Catalog Name."
    type        = string
}

variable "database_name" {
    description = "The CCAF Database Name."
    type        = string
}

variable "ccaf_secret_path" {
    description = "The CCAF AWS Secrets Manager secrets path."
    type        = string
    default     = ""
}

variable "aws_lambda_memory_size" {
    description = "AWS Lambda allocates CPU power in proportion to the amount of memory configured. Memory is the amount of memory available to your Lambda function at runtime. You can increase or decrease the memory and CPU power allocated to your function using the Memory setting. You can configure memory between 128 MB and 10,240 MB in 1-MB increments. At 1,769 MB, a function has the equivalent of one vCPU (one vCPU-second of credits per second)."
    type = number
    default = 128
    
    validation {
        condition = var.aws_lambda_memory_size >= 128 && var.aws_lambda_memory_size <= 10240
        error_message = "AWS Lambda memory size, `aws_lambda_memory_size`, must be 1 up to a maximum value of 10,240."
    }
}

variable "aws_lambda_timeout" {
    description = "AWS Lambda runs your code for a set amount of time before timing out. Timeout is the maximum amount of time in seconds that a Lambda function can run. The default value for this setting is 900 seconds, but you can adjust this in increments of 1 second up to a maximum value of 900 seconds (15 minutes)."
    type = number
    default = 900
    
    validation {
        condition = var.aws_lambda_timeout >= 1 && var.aws_lambda_timeout <= 900
        error_message = "AWS Lambda timeout, `aws_lambda_timeout`, must be 1 up to a maximum value of 900."
    }
}

variable "aws_log_retention_in_days" {
    description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0. If you select 0, the events in the log group are always retained and never expire."
    type = number
    default = 7

    validation {
        condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.aws_log_retention_in_days)
        error_message = "AWS Log Retention in Days, `aws_log_retention_in_days`, must be 1 up to a maximum value of 900."
    }
}