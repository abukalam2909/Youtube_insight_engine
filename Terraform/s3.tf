resource "aws_s3_bucket" "yt_raw_data" {
  bucket         = "yt-raw-data-bucket-abu-kalam"
  force_destroy  = true

  tags = {
    Name = "YouTube Raw Data Bucket"
  }
}
