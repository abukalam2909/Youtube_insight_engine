resource "aws_iam_role" "lambda_admin_role" {
  name = "LambdaAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_full" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role_policy_attachment" "dynamodb_full" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "comprehend" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/ComprehendFullAccess"
}

# resource "aws_iam_policy" "opensearch_access" {
#   name = "LambdaOpenSearchAccess"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect   = "Allow",
#       Action   = ["es:ESHttpPost", "es:ESHttpPut", "es:ESHttpGet"],
#       Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/youtube-comments/*"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "attach_opensearch" {
#   role       = aws_iam_role.lambda_admin_role.name
#   policy_arn = aws_iam_policy.opensearch_access.arn
# }

resource "aws_iam_policy" "bedrock_invoke" {
  name = "LambdaBedrockInvokeModelPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_bedrock_invoke" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

# Lambda permissions
resource "aws_lambda_permission" "ingest_permission" {
  statement_id  = "AllowInvokeIngest"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "llm_permission" {
  statement_id  = "AllowInvokeLLM"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.llm.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
