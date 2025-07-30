# Terraform variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}
variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
}
