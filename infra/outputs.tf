output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the React app"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "api_gateway_endpoint" {
  description = "Base URL for the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "dynamodb_courses_table" {
  description = "DynamoDB table name for GolfCourses"
  value       = aws_dynamodb_table.GolfCourses.name
}

output "secretsmanager_openai_arn" {
  description = "ARN of the OpenAI API key secret"
  value       = aws_secretsmanager_secret.openai.arn
}