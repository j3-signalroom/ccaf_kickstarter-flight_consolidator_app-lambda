data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create the Lambda execution role and policy
resource "aws_iam_role" "flight_consolidator_lambda" {
  name = "ccaf_flight_consolidator_app_role"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "flight_consolidator_lambda_policy" {
  name        = "ccaf_flight_consolidator_app_policy"
  description = "IAM policy for the flight_consolidator Lambda execution role."
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Effect   = "Allow",
        Resource = local.ecr_repo_uri
      },
      {
        Action = "ecr:GetAuthorizationToken",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "flight_consolidator_lambda_policy_attachment" {
  role       = aws_iam_role.flight_consolidator_lambda.name
  policy_arn = aws_iam_policy.flight_consolidator_lambda_policy.arn

  depends_on = [ 
    aws_iam_role.flight_consolidator_lambda,
    aws_iam_policy.flight_consolidator_lambda_policy 
  ]
}

# Lambda function
resource "aws_lambda_function" "flight_consolidator_lambda_function" {
  function_name = "ccaf_flight_consolidator_app_function"
  role          = aws_iam_role.flight_consolidator_lambda.arn
  package_type  = "Image"
  image_uri     = local.repo_uri
  memory_size   = var.aws_lambda_memory_size
  timeout       = var.aws_lambda_timeout

  depends_on = [ aws_iam_role.flight_consolidator_lambda ]
}

# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "flight_consolidator_lambda_function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.flight_consolidator_lambda_function.function_name}"
  retention_in_days = var.aws_log_retention_in_days
}

# Lambda function invocation
resource "aws_lambda_invocation" "flight_consolidator_lambda_function" {
  function_name = aws_lambda_function.flight_consolidator_lambda_function.function_name

  input = jsonencode({
    catalog_name     = var.catalog_name
    database_name    = var.database_name
    ccaf_secret_path = var.ccaf_secret_path
  })

  depends_on = [ 
    aws_lambda_function.flight_consolidator_lambda_function
  ]
}
