# terraform/outputs.tf
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.griffler_api.api_endpoint
}

output "dashboard_bucket" {
  description = "S3 bucket name for dashboard"
  value       = aws_s3_bucket.dashboard.id
}

output "dashboard_website_endpoint" {
  description = "Dashboard website endpoint"
  value       = aws_s3_bucket_website_configuration.dashboard.website_endpoint
}

output "artifacts_bucket" {
  description = "S3 bucket name for artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.test_runs.name
}

output "lambda_functions" {
  description = "Lambda function ARNs"
  value = {
    create_test_run    = aws_lambda_function.create_test_run.arn
    get_test_runs      = aws_lambda_function.get_test_runs.arn
    get_test_run_by_id = aws_lambda_function.get_test_run_by_id.arn
    update_test_run    = aws_lambda_function.update_test_run.arn
    upload_artifact    = aws_lambda_function.upload_artifact.arn
    get_artifact       = aws_lambda_function.get_artifact.arn
  }
}
