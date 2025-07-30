# Terraform outputs
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}
