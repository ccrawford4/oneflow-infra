output "instance_public_dns" {
    value = aws_instance.web.public_dns
}
output "rds_endpoint" {
    value = aws_db_instance.oneflow_database.endpoint
}
output "aws_ec2_instance_connect_endpoint" {
  value = aws_ec2_instance_connect_endpoint.oneflow_instance_connect.dns_name
}