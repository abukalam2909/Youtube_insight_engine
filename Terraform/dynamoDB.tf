resource "aws_dynamodb_table" "youtube_metadata" {
  name         = "YouTubeMetadataTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "VideoId"

  attribute {
    name = "VideoId"
    type = "S"
  }

  tags = {
    Name = "YouTube Metadata Table"
  }
}
