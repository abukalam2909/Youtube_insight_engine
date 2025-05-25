
provider "aws" {
  region = "us-east-1"
}

variable "youtube_api_key" {
  description = "YouTube Data API Key"
  type        = string
}

resource "aws_s3_bucket" "yt_raw_data" {
  bucket = "yt-raw-data-bucket-abu-kalam"
  force_destroy = true

  tags = {
    Name = "YouTube Raw Data Bucket"
  }
}

resource "aws_dynamodb_table" "youtube_metadata" {
  name           = "YouTubeMetadataTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "VideoId"

  attribute {
    name = "VideoId"
    type = "S"
  }

  tags = {
    Name = "YouTube Metadata Table"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_admin_role" {
  name = "LambdaAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_full" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

resource "aws_lambda_function" "youtube_ingest" {
  function_name = "YouTubeIngestFunction"
  runtime       = "python3.9"
  timeout       = 5
  handler       = "lambda_youtube_ingest.lambda_handler"

  filename         = "../Lambda/lambda_youtube_ingest.zip"
  source_code_hash = filebase64sha256("../Lambda/lambda_youtube_ingest.zip")

  environment {
    variables = {
      YOUTUBE_API_KEY = var.youtube_api_key
      S3_BUCKET       = aws_s3_bucket.yt_raw_data.bucket
      DYNAMODB_TABLE  = aws_dynamodb_table.youtube_metadata.name
    }
  }

  role = aws_iam_role.lambda_admin_role.arn
}

resource "aws_lambda_function" "youtube_nlp_analysis" {
  function_name = "YouTubeNLPAnalysisFunction"
  runtime       = "python3.9"
  timeout       = 60
  handler       = "lambda_nlp_sentiment_analysis.lambda_handler"

  filename         = "../Lambda/lambda_nlp_sentiment_analysis.zip"
  source_code_hash = filebase64sha256("../Lambda/lambda_nlp_sentiment_analysis.zip")

  environment {
    variables = {
      YOUTUBE_API_KEY = var.youtube_api_key
      DYNAMODB_TABLE  = aws_dynamodb_table.youtube_metadata.name
    }
  }

  role = aws_iam_role.lambda_admin_role.arn
}
