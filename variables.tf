variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "subnet_count" {
    description = "Number of subnets"
    type = map(number)
    default = {
        public = 1,
        private = 2
    }
}
variable "settings" {
  description = "Configuration settings"
  type        = map(any)
  default = {
    "database" = {
      engine                 = "mysql"
      name                   = "product"
      engine_version         = "8.0.40"
      skip_final_snapshot    = true
      dev_allocated_storage  = 10
      prod_allocated_storage = 20
      dev_instance_type      = "db.t3.micro"
      prod_instance_type     = "db.t4g.large"
    },
    "web_app" = {
      dev_instance_type  = "t4g.nano"
      prod_instance_type = "t4g.large"
      count              = 1
      source_ami_id      = "ami-09865693345bd0d76"
      source_ami_region  = "us-east-2"
    }
  }
}
variable "public_subnet_cidr_blocks" {
  description = "Available CIDR blocks for public subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]
}
variable "private_subnet_cidr_blocks" {
  description = "Available CIDR blocks for private subnets"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
    "10.0.104.0/24",
  ]
}
variable "environment" {
    description = "The environment in which the resources are deployed."
    type = string
    default = "dev"
}
variable "db_username" {
    description = "The username for the database."
    type = string
    default = "admin"
}
variable "db_password" {
    description = "The password for the database."
    type = string
    default = "change-me-in-production"
}
variable "db_name" {
    description = "The name of the database"
    type = string
    default = "oneflow_dev"
}
variable "db_port" {
    description = "The port number for the database"
    type = number
    default = 3306
}
variable "aws_account_id" {
    description = "The AWS account ID."
    type = string
}
