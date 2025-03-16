output "instance_public_dns" {
    value = aws_instance.web.public_dns
}
output "rds_endpoint" {
    value = aws_db_instance.oneflow_database.endpoint
}
output "key_name" {
    value = local.key_name
}
output "s3_bucket_name" {
    value = local.bucket_name
}
