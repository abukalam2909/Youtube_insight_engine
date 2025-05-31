resource "aws_lambda_function" "youtube_ingest" {
  function_name = "YouTubeIngestFunction"
  runtime       = "python3.9"
  timeout       = 900  # Increased timeout
  handler       = "lambda_youtube_ingest.lambda_handler"
  memory_size   = 256

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
  timeout       = 900  # 15 minutes - increased for processing
  handler       = "lambda_nlp_sentiment_analysis.lambda_handler"
  memory_size   = 1024  # Increased memory for Comprehend processing

  filename         = "../Lambda/lambda_nlp_sentiment_analysis.zip"
  source_code_hash = filebase64sha256("../Lambda/lambda_nlp_sentiment_analysis.zip")

  environment {
    variables = {
      YOUTUBE_API_KEY = var.youtube_api_key
      DYNAMODB_TABLE  = aws_dynamodb_table.youtube_metadata.name
      REGION      = var.aws_region
    }
  }

  role = aws_iam_role.lambda_admin_role.arn
}

resource "aws_lambda_function" "youtube_fetch_results" {
  function_name = "DynamoDBFetchResults"
  runtime       = "python3.9"
  timeout       = 900  # 15 minutes - increased for processing
  handler       = "lambda_fetch_results.lambda_handler"
  memory_size   = 256  # Increased memory for Comprehend processing

  filename         = "../Lambda/lambda_fetch_results.zip"
  source_code_hash = filebase64sha256("../Lambda/lambda_fetch_results.zip")

  environment {
    variables = {
      DYNAMODB_TABLE  = aws_dynamodb_table.youtube_metadata.name
      REGION      = var.aws_region
    }
  }

  role = aws_iam_role.lambda_admin_role.arn
}

resource "aws_lambda_function" "llm_insights" {
  function_name = "LLMInsightFunction"
  runtime       = "python3.9"
  timeout       = 60
  handler       = "lambda_llm_insight.lambda_handler"
  memory_size   = 512

  filename         = "../Lambda/lambda_llm_insight.zip"
  source_code_hash = filebase64sha256("../Lambda/lambda_llm_insight.zip")

  environment {
    variables = {
      DYNAMODB_TABLE      = aws_dynamodb_table.youtube_metadata.name
      REGION              = var.aws_region
      BEDROCK_MODEL_ID    = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }

  role = aws_iam_role.lambda_admin_role.arn
}
