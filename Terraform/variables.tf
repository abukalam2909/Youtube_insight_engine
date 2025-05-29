variable "aws_region" {
  default     = "us-east-1"
  description = "AWS region to deploy resources in"
}

variable "youtube_api_key" {
  description = "YouTube Data API Key"
  type        = string
}
