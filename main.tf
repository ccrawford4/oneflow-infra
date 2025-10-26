# Create S3 bucket
resource "aws_s3_bucket" "my_app_data" {
  bucket = "my-app-data"
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "my_app_data_versioning" {
  bucket = aws_s3_bucket.my_app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "my_app_data_public_access" {
  bucket = aws_s3_bucket.my_app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}