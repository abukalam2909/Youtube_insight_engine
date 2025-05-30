resource "aws_s3_bucket" "yt_raw_data" {
  bucket        = "yt-raw-data-bucket-abu-kalam"
  force_destroy = true

  tags = {
    Name = "YouTube Raw Data Bucket"
  }
}

resource "aws_s3_bucket" "frontend_ui" {
  bucket        = "youtube-analyzer-frontend-ui"
  force_destroy = true

  tags = {
    Name = "YouTube Frontend UI Bucket"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_ui" {
  bucket = aws_s3_bucket.frontend_ui.bucket

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_ui_block" {
  bucket = aws_s3_bucket.frontend_ui.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend_ui.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_ui.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend_ui_block
  ]
}
