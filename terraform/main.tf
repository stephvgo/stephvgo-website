#s3 bucket
resource "aws_s3_bucket" "website_bucket" {
  bucket = "steph-vgo-website"

  tags = {
    Name = "steph-vgo-website"
  }
}

#s3 bucket versioning
resource "aws_s3_bucket_versioning" "website_versioning" {
  bucket = aws_s3_bucket.website_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# website hosting config
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# website public access
resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#bucket policy
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

#dynamodb table
resource "aws_dynamodb_table" "visitor_count" {
  name         = "visitor-count"        
  billing_mode = "PAY_PER_REQUEST"      
  hash_key     = "CounterName"          

  attribute {                            
    name = "CounterName"
    type = "S"
  }
}

#iam role for lambda
resource "aws_iam_role" "lambda_role" {
  name = "visitor-count-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

#basic lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name 
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"  # AWS managed policy
}

#custom iam policy so lambda can write to dynamodb table
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.visitor_count.arn
      }
    ]
  })
}

# lambda function
resource "aws_lambda_function" "visitor_counter" {
  function_name = "visitor-count"
  role          = aws_iam_role.lambda_role.arn
  handler       = "code.lambda_handler"
  runtime       = "python3.14"    

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
}

#API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "visitor-count-api"
  protocol_type = "HTTP"
}

#integration: connection api gateway to lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.visitor_counter.invoke_arn
  payload_format_version = "2.0"
}

# count route
resource "aws_apigatewayv2_route" "count_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# deploy block
resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "dev"
  auto_deploy = true
}

# lambda permission for api gateway to call on lambda
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
