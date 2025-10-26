# Create S3 bucket for app data
resource "aws_s3_bucket" "app_data" {
  bucket = "my-app-data"
}

resource "aws_s3_bucket_versioning" "app_data_versioning" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}