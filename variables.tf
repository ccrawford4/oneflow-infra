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
}
variable "db_password" {
    description = "The password for the database."
    type = string
}
variable "db_name" {
    description = "The name of the database"
    type = string
}
variable "db_port" {
    description = "The port number for the database"
    type = number
}
variable "aws_account_id" {
    description = "The AWS account ID."
    type = string
}
