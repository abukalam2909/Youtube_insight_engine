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

resource "aws_s3_bucket_cors_configuration" "frontend_ui_cors" {
  bucket = aws_s3_bucket.frontend_ui.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Frontend files

resource "local_file" "env_config" {
  content = <<-EOT
    window._env_ = {
      API_BASE_URL: "${aws_apigatewayv2_api.http_api.api_endpoint}"
    };
  EOT

  filename = "${path.module}/../youtube-analysis-frontend/js/env-config.js"
}

resource "null_resource" "wait_for_env_config" {
  provisioner "local-exec" {
    command = "sleep 1 && test -f ../youtube-analysis-frontend/js/env-config.js"
  }

  depends_on = [local_file.env_config]
}


locals {
  frontend_build_dir = "${path.module}/../youtube-analysis-frontend"
  frontend_files     = fileset(local.frontend_build_dir, "**/*.*")
}

resource "aws_s3_object" "frontend_assets" {
  for_each = { for file in local.frontend_files : file => file }

  bucket       = aws_s3_bucket.frontend_ui.id
  key          = each.value
  source       = "${local.frontend_build_dir}/${each.value}"
  etag         = filemd5("${local.frontend_build_dir}/${each.value}")
  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      json = "application/json"
      png  = "image/png"
      jpg  = "image/jpeg"
      svg  = "image/svg+xml"
      ico  = "image/x-icon"
      txt  = "text/plain"
    },
    lower(trimspace(regex("\\.([^.]+)$", each.value)[0])),
    "application/octet-stream"
  )

  depends_on = [null_resource.wait_for_env_config]
}



