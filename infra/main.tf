provider "aws" {
  region = "us-east-2"
}

# ========== IAM Roles & Policies ==========
resource "aws_iam_role" "lambda_exec" {
  name = "kinetech-tee-time-lambda-exec"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" }
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamodb_ses" {
  name   = "kinetech-tee-time-dyn-ses"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": [
        "${aws_dynamodb_table.GolfCourses.arn}",
        "${aws_dynamodb_table.Bookings.arn}",
        "${aws_secretsmanager_secret.openai.arn}",
        ""${aws_secretsmanager_secret.sendgrid.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail","ses:SendRawEmail"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "${aws_secretsmanager_secret.openai.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_ses_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamodb_ses.arn
}

# ========== DynamoDB Tables ==========
resource "aws_dynamodb_table" "GolfCourses" {
  name         = "GolfCourses"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "courseId"

  attribute {
    name = "courseId"
    type = "S"
  }
  attribute {
    name = "zip"
    type = "S"
  }

  global_secondary_index {
    name            = "ZipIndex"
    hash_key        = "zip"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "Bookings" {
  name         = "Bookings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "bookingId"

  attribute {
    name = "bookingId"
    type = "S"
  }
}

# ========== Secrets Manager ==========
resource "aws_secretsmanager_secret" "openai" {
  name = "prod/openai/api_key"
}
resource "aws_secretsmanager_secret_version" "openai_value" {
  secret_id     = aws_secretsmanager_secret.openai.id
  secret_string = var.openai_api_key
}

# ========== SES Configuration ==========
resource "aws_ses_domain_identity" "identity" {
  domain = "kinetechteetimeapp.com"
}
resource "aws_ses_email_identity" "from_address" {
  email = "hassaan.mehmood@kinetechcloud.com"
}

# ========== S3 + CloudFront ==========
resource "aws_s3_bucket" "frontend" {
  bucket = "kinetechteetimeapp-frontend"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for kinetechteetimeapp frontend"
}

data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-frontend"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods    = ["GET","HEAD","OPTIONS"]
    cached_methods     = ["GET","HEAD"]
    target_origin_id   = "S3-frontend"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
}

# ========== ACM Certificate ==========
resource "aws_acm_certificate" "cert" {
  domain_name       = "kinetechteetimeapp.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ========== Route53 ==========
resource "aws_route53_zone" "main" {
  name = "kinetechteetimeapp.com"
}
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "kinetechteetimeapp.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# ========== Lambda Functions ==========
resource "aws_lambda_function" "chat_handler" {
  function_name    = "chatHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "${path.module}/chatHandler.zip"
  source_code_hash = filebase64sha256("${path.module}/chatHandler.zip")
  environment {
    variables = {
      SES_FROM_ADDRESS = "hassaan.mehmood@kinetechcloud.com"
    }
  }
}

resource "aws_lambda_function" "search_handler" {
  function_name    = "searchHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "${path.module}/searchHandler.zip"
  source_code_hash = filebase64sha256("${path.module}/searchHandler.zip")
}

resource "aws_lambda_function" "booking_handler" {
  function_name    = "bookingHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "${path.module}/bookingHandler.zip"
  source_code_hash = filebase64sha256("${path.module}/bookingHandler.zip")
  environment {
    variables = {
      SES_FROM_ADDRESS = "hassaan.mehmood@kinetechcloud.com"
    }
  }
}

# ========== API Gateway ==========
resource "aws_api_gateway_rest_api" "api" {
  name        = "teeTimeApi"
  description = "API for KineTech TeeTime App"
}

# Chat endpoint
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "chat"
}
resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "chat_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chat_handler.invoke_arn
}

# Search endpoint
resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "search"
}
resource "aws_api_gateway_method" "search_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "search_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.search.id
  http_method             = aws_api_gateway_method.search_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_handler.invoke_arn
}

# Booking endpoint
resource "aws_api_gateway_resource" "booking" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "booking"
}
resource "aws_api_gateway_method" "booking_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.booking.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "booking_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.booking.id
  http_method             = aws_api_gateway_method.booking_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.booking_handler.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers    = { redeployment = filemd5("${path.module}/main.tf") }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id    = aws_api_gateway_rest_api.api.id
  stage_name     = "prod"
  deployment_id  = aws_api_gateway_deployment.deployment.id
}

resource "aws_secretsmanager_secret" "sendgrid" {
  name = "prod/sendgrid/api_key"
}

resource "aws_secretsmanager_secret_version" "sendgrid_value" {
  secret_id     = aws_secretsmanager_secret.sendgrid.id
  secret_string = jsonencode({ SENDGRID_API_KEY = var.sendgrid_api_key })
}
