resource "random_string" "random" {
  length = 8
  special = false
  upper = false
}

locals {
  current_timestamp = "${formatdate("YYYYMMDDhhmmss", timestamp())}"
  instance_type     = var.environment == "dev" ? var.settings.web_app.dev_instance_type : var.settings.web_app.prod_instance_type
  db_instance_class = var.environment == "dev" ? var.settings.database.dev_instance_type : var.settings.database.prod_instance_type
  allocated_storage = var.environment == "dev" ? var.settings.database.dev_allocated_storage : var.settings.database.prod_allocated_storage
  key_name = "${var.environment}-oneflow-key-${terraform.workspace}-${random_string.random.id}" # Use timestamp to avoid repeat key names in AWS secrets
  bucket_name = "${var.environment}-oneflow-bucket-${random_string.random.id}" # Use timestamp to avoid repeat bucket names

  common_tags = {
    Environment = var.environment
    Project     = "oneflow"
  }
}

provider "aws" {
  region = terraform.workspace

  default_tags {
    tags = local.common_tags
  }
}

terraform {
  backend "s3" {
    bucket = "oneflow-terraform-state-10080483"
    key = "terraform.tfstate"
    region = "us-east-2"
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

# Create the AMI copy for the desired region
resource "aws_ami_copy" "oneflow_ami_copy" {
  name = "oneflow_ami_copy"
  source_ami_id = var.settings.web_app.source_ami_id
  source_ami_region = var.settings.web_app.source_ami_region

  tags = {
    Name = "oneflow_ami_copy"
  }
}

# Create IAM role for EC2 instance
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "ec2_s3_access_role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Create IAM policy for S3 access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3_access_policy-${terraform.workspace}"
  description = "Policy to allow access to specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*"
        ]
      },
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

# Create S3 bucket
resource "aws_s3_bucket" "oneflow_bucket" {
  bucket = local.bucket_name
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.oneflow_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy to deny access from anywhere except the EC2 instance's role
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.oneflow_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn": [
              aws_iam_role.ec2_s3_access_role.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
            ]
          }
        }
      },
      {
        Effect    = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.ec2_s3_access_role.arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
          ]
        }
        Action    = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.block_public_access]
}

# Create the EC2 instance
resource "aws_instance" "web" {
  associate_public_ip_address = true
  ami                         = aws_ami_copy.oneflow_ami_copy.id
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.oneflow_public_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name      = aws_key_pair.generated_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

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
  name = "oneflow_db_subnet_group-${terraform.workspace}"

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
  db_name                = var.db_name
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
