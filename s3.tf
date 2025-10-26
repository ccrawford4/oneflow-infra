resource "aws_s3_bucket" "my_app_data" {
  bucket = "my-app-data"
}

resource "aws_s3_bucket_versioning" "my_app_data_versioning" {
  bucket = aws_s3_bucket.my_app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}