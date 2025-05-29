resource "aws_lambda_function" "youtube_ingest" {
  function_name = "YouTubeIngestFunction"
  runtime       = "python3.9"
  timeout       = 5
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
  timeout       = 60
  handler       = "lambda_nlp_sentiment_analysis.lambda_handler"
  memory_size   = 512

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

# resource "aws_lambda_function" "vectorize_and_store" {
#   function_name = "YouTubeVectorizeAndStoreFunction"
#   runtime       = "python3.11"
#   timeout       = 120
#   memory_size   = 512
#   handler       = "lambda_vectorize_store.lambda_handler"

#   filename         = "../Lambda/lambda_vectorize_store.zip"
#   source_code_hash = filebase64sha256("../Lambda/lambda_vectorize_store.zip")

#   environment {
#     variables = {
#       DYNAMODB_TABLE      = aws_dynamodb_table.youtube_metadata.name
#       OPENSEARCH_ENDPOINT = aws_opensearch_domain.youtube_comments.endpoint
#       REGION              = var.aws_region
#       BEDROCK_MODEL_ID    = "amazon.titan-embed-text-v1"
#     }
#   }

#   role = aws_iam_role.lambda_admin_role.arn
# }

# resource "aws_lambda_function" "retrieve_comments" {
#   function_name = "YouTubeRetrieveCommentsFunction"
#   runtime       = "python3.11"
#   timeout       = 60
#   memory_size   = 512
#   handler       = "lambda_retrieve_comments.lambda_handler"

#   filename         = "../Lambda/lambda_retrieve_comments.zip"
#   source_code_hash = filebase64sha256("../Lambda/lambda_retrieve_comments.zip")

#   environment {
#     variables = {
#       REGION              = var.aws_region
#       OPENSEARCH_ENDPOINT = aws_opensearch_domain.youtube_comments.endpoint
#       BEDROCK_MODEL_ID    = "amazon.titan-embed-text-v1"  
#     }
#   }

#   role = aws_iam_role.lambda_admin_role.arn
# }
