
# Fetch Lambda ARNs
data "aws_lambda_function" "ingest" {
  function_name = aws_lambda_function.youtube_ingest.function_name
}

data "aws_lambda_function" "llm" {
  function_name = aws_lambda_function.llm_insights.function_name
}

# Create API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "YouTubeAnalyzerAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

# # Lambda permissions
# resource "aws_lambda_permission" "ingest_permission" {
#   statement_id  = "AllowInvokeIngest"
#   action        = "lambda:InvokeFunction"
#   function_name = data.aws_lambda_function.ingest.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
# }

# resource "aws_lambda_permission" "llm_permission" {
#   statement_id  = "AllowInvokeLLM"
#   action        = "lambda:InvokeFunction"
#   function_name = data.aws_lambda_function.llm.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
# }

# Integrations
resource "aws_apigatewayv2_integration" "ingest_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.ingest.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "llm_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.llm.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "ingest_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /ingest-channel"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_integration.id}"
}

resource "aws_apigatewayv2_route" "llm_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /analyze-comments"
  target    = "integrations/${aws_apigatewayv2_integration.llm_integration.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}
