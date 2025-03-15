locals {
  instance_type     = var.environment == "dev" ? var.settings.web_app.dev_instance_type : var.settings.web_app.prod_instance_type
  db_instance_class = var.environment == "dev" ? var.settings.database.dev_instance_type : var.settings.database.prod_instance_type
  allocated_storage = var.environment == "dev" ? var.settings.database.dev_allocated_storage : var.settings.database.prod_allocated_storage
  key_name = "${var.environment}-oneflow-key-${var.aws_region}-${formatdate("YYYYMMDDhhmmss", timestamp())}" # Use current time to avoid repeat key names in AWS secrets

  common_tags = {
    Environment = var.environment
    Project     = "oneflow"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Get the available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Gets the current AWS account info
data "aws_caller_identity" "current" {}

# Create the VPC
resource "aws_vpc" "oneflow_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "oneflow_vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "oneflow_igw" {
  vpc_id = aws_vpc.oneflow_vpc.id

  tags = {
    Name = "oneflow_igw"
  }
}

# Create a public subnet
resource "aws_subnet" "oneflow_public_subnet" {
  count                   = var.subnet_count.public
  vpc_id                  = aws_vpc.oneflow_vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "oneflow_public_subnet_${count.index}"
  }
}

# Create a private subnet
resource "aws_subnet" "oneflow_private_subnet" {
  count             = var.subnet_count.private
  vpc_id            = aws_vpc.oneflow_vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "oneflow_private_subnet_${count.index}"
  }
}

# Create a public route table
resource "aws_route_table" "oneflow_public_rt" {
  vpc_id = aws_vpc.oneflow_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.oneflow_igw.id
  }
}

# Create the private route table
resource "aws_route_table" "oneflow_private_rt" {
  vpc_id = aws_vpc.oneflow_vpc.id
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public" {
  count          = var.subnet_count.public
  route_table_id = aws_route_table.oneflow_public_rt.id
  subnet_id      = aws_subnet.oneflow_public_subnet[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.subnet_count.private
  route_table_id = aws_route_table.oneflow_private_rt.id
  subnet_id      = aws_subnet.oneflow_private_subnet[count.index].id
}

# Creates the security group for the EC2 instance
resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.oneflow_vpc.id

  # Inbound inbound HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # Allow inbound SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    description = "SSH from VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "oneflow"
  }
}
# Generate SSH Key Pair
resource "tls_private_key" "ec2_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store Public Key in AWS EC2 Key Pair
resource "aws_key_pair" "generated_key" {
  key_name   = local.key_name
  public_key = tls_private_key.ec2_ssh_key.public_key_openssh
}

# Store Private Key in Secrets Manager
resource "aws_secretsmanager_secret" "ssh_key_secret" {
  name                    = local.key_name
  description             = "Private SSH key for EC2 instance access"
}

resource "aws_secretsmanager_secret_version" "ssh_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.ssh_key_secret.id
  secret_string = jsonencode({
    private_key = tls_private_key.ec2_ssh_key.private_key_pem
  })
}

# Create the EC2 instance
resource "aws_instance" "web" {
  associate_public_ip_address = true
  ami                         = var.settings.web_app.ami
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.oneflow_public_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name      = aws_key_pair.generated_key.key_name

  tags = {
    Name = "oneflow_app"
  }
}

# Create the security group for the RDS instance
resource "aws_security_group" "oneflow_db_sg" {
  name   = "oneflow_db_sg"
  vpc_id = aws_vpc.oneflow_vpc.id

  # Inbound rule for MySQL traffic from the EC2 isntance
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_sg.id]
  }

  tags = {
    Name = "oneflow_db_sg"
  }
}

# Create a db subnet group named oneflow_db_subnet_group
resource "aws_db_subnet_group" "oneflow_db_subnet_group" {
  name = "oneflow_db_subnet_group"

  # add all the private subnets to the db subnet group
  subnet_ids = aws_subnet.oneflow_private_subnet.*.id
  tags = {
    Name = "oneflow_db_subnet_group"
  }

  lifecycle {
      create_before_destroy = true
  }
}

# Create the RDS instance
resource "aws_db_instance" "oneflow_database" {
  allocated_storage      = local.allocated_storage
  engine                 = var.settings.database.engine
  engine_version         = var.settings.database.engine_version
  instance_class         = local.db_instance_class
  db_name                = var.settings.database.name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.oneflow_db_subnet_group.id
  vpc_security_group_ids = aws_security_group.oneflow_db_sg.*.id
  skip_final_snapshot    = var.settings.database.skip_final_snapshot

  tags = {
    Name        = "oneflow_database"
  }

  depends_on = [aws_db_subnet_group.oneflow_db_subnet_group]
}
