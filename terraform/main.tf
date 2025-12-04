# terraform/main.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Uncomment for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "griffler/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Table for Test Runs
resource "aws_dynamodb_table" "test_runs" {
  name           = "${var.project_name}-test-runs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  global_secondary_index {
    name            = "timestamp-index"
    hash_key        = "timestamp"
    projection_type = "ALL"
  }
  
  tags = {
    Name        = "${var.project_name}-test-runs"
    Environment = var.environment
  }
}

# S3 Bucket for Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${var.environment}"
  
  tags = {
    Name        = "${var.project_name}-artifacts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for Griffler Dashboard (Static Website)
resource "aws_s3_bucket" "dashboard" {
  bucket = "${var.project_name}-dashboard-${var.environment}"
  
  tags = {
    Name        = "${var.project_name}-dashboard"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_website_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  
  index_document {
    suffix = "index.html"
  }
  
  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dashboard.arn}/*"
      }
    ]
  })
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.test_runs.arn,
          "${aws_dynamodb_table.test_runs.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "create_test_run" {
  filename         = "../lambda/create_test_run.zip"
  function_name    = "${var.project_name}-create-test-run"
  role            = aws_iam_role.lambda_role.arn
  handler         = "createTestRun.handler"
  source_code_hash = filebase64sha256("../lambda/create_test_run.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      TEST_RUNS_TABLE = aws_dynamodb_table.test_runs.name
    }
  }
  
  tags = {
    Name        = "${var.project_name}-create-test-run"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "get_test_runs" {
  filename         = "../lambda/get_test_runs.zip"
  function_name    = "${var.project_name}-get-test-runs"
  role            = aws_iam_role.lambda_role.arn
  handler         = "getTestRuns.handler"
  source_code_hash = filebase64sha256("../lambda/get_test_runs.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      TEST_RUNS_TABLE = aws_dynamodb_table.test_runs.name
    }
  }
  
  tags = {
    Name        = "${var.project_name}-get-test-runs"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "get_test_run_by_id" {
  filename         = "../lambda/get_test_run_by_id.zip"
  function_name    = "${var.project_name}-get-test-run-by-id"
  role            = aws_iam_role.lambda_role.arn
  handler         = "getTestRunById.handler"
  source_code_hash = filebase64sha256("../lambda/get_test_run_by_id.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      TEST_RUNS_TABLE = aws_dynamodb_table.test_runs.name
    }
  }
  
  tags = {
    Name        = "${var.project_name}-get-test-run-by-id"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "update_test_run" {
  filename         = "../lambda/update_test_run.zip"
  function_name    = "${var.project_name}-update-test-run"
  role            = aws_iam_role.lambda_role.arn
  handler         = "updateTestRun.handler"
  source_code_hash = filebase64sha256("../lambda/update_test_run.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      TEST_RUNS_TABLE = aws_dynamodb_table.test_runs.name
    }
  }
  
  tags = {
    Name        = "${var.project_name}-update-test-run"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "upload_artifact" {
  filename         = "../lambda/upload_artifact.zip"
  function_name    = "${var.project_name}-upload-artifact"
  role            = aws_iam_role.lambda_role.arn
  handler         = "uploadArtifact.handler"
  source_code_hash = filebase64sha256("../lambda/upload_artifact.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      TEST_RUNS_TABLE  = aws_dynamodb_table.test_runs.name
      ARTIFACTS_BUCKET = aws_s3_bucket.artifacts.id
    }
  }
  
  tags = {
    Name        = "${var.project_name}-upload-artifact"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "get_artifact" {
  filename         = "../lambda/get_artifact.zip"
  function_name    = "${var.project_name}-get-artifact"
  role            = aws_iam_role.lambda_role.arn
  handler         = "getArtifact.handler"
  source_code_hash = filebase64sha256("../lambda/get_artifact.zip")
  runtime         = "nodejs20.x"
  timeout         = 30
  
  environment {
    variables = {
      ARTIFACTS_BUCKET = aws_s3_bucket.artifacts.id
    }
  }
  
  tags = {
    Name        = "${var.project_name}-get-artifact"
    Environment = var.environment
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "griffler_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }
  
  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.griffler_api.id
  name        = "$default"
  auto_deploy = true
  
  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
  }
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "create_test_run" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_test_run.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_test_runs" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_test_runs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_test_run_by_id" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_test_run_by_id.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "update_test_run" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_test_run.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "upload_artifact" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_artifact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_artifact" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_artifact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.griffler_api.execution_arn}/*/*"
}

# API Gateway Integrations
resource "aws_apigatewayv2_integration" "create_test_run" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.create_test_run.invoke_arn
}

resource "aws_apigatewayv2_integration" "get_test_runs" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_test_runs.invoke_arn
}

resource "aws_apigatewayv2_integration" "get_test_run_by_id" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_test_run_by_id.invoke_arn
}

resource "aws_apigatewayv2_integration" "update_test_run" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.update_test_run.invoke_arn
}

resource "aws_apigatewayv2_integration" "upload_artifact" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.upload_artifact.invoke_arn
}

resource "aws_apigatewayv2_integration" "get_artifact" {
  api_id           = aws_apigatewayv2_api.griffler_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_artifact.invoke_arn
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "create_test_run" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "POST /test-runs"
  target    = "integrations/${aws_apigatewayv2_integration.create_test_run.id}"
}

resource "aws_apigatewayv2_route" "get_test_runs" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "GET /test-runs"
  target    = "integrations/${aws_apigatewayv2_integration.get_test_runs.id}"
}

resource "aws_apigatewayv2_route" "get_test_run_by_id" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "GET /test-runs/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_test_run_by_id.id}"
}

resource "aws_apigatewayv2_route" "update_test_run" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "PATCH /test-runs/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.update_test_run.id}"
}

resource "aws_apigatewayv2_route" "upload_artifact" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "POST /test-runs/{id}/artifacts"
  target    = "integrations/${aws_apigatewayv2_integration.upload_artifact.id}"
}

resource "aws_apigatewayv2_route" "get_artifact" {
  api_id    = aws_apigatewayv2_api.griffler_api.id
  route_key = "GET /test-runs/{id}/artifacts/{filename}"
  target    = "integrations/${aws_apigatewayv2_integration.get_artifact.id}"
}
