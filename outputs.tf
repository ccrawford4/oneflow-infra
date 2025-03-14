output "instance_public_dns" {
    value = aws_instance.web.public_dns
}
output "rds_endpoint" {
    value = aws_db_instance.oneflow_database.endpoint
}
output "s3_vpc_endpoint" {
    value = aws_vpc_endpoint.s3.dns_entry
}
output "s3_vpc_endpoint_id" {
  value       = aws_vpc_endpoint.s3.id
}
output "s3_vpc_endpoint_state" {
  value       = aws_vpc_endpoint.s3.state
}
output "s3_vpc_endpoint_route_tables" {
  value       = aws_vpc_endpoint.s3.route_table_ids
}