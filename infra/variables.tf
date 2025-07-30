# Terraform variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "openai_api_key" {
  description = "API key for OpenAI stored in Secrets Manager"
  type        = string
}

