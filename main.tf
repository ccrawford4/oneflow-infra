locals {
  instance_type     = var.environment == "dev" ? var.settings.web_app.dev_instance_type : var.settings.web_app.prod_instance_type
  db_instance_class = var.environment == "dev" ? var.settings.database.dev_instance_type : var.settings.database.prod_instance_type
  allocated_storage = var.environment == "dev" ? var.settings.database.dev_allocated_storage : var.settings.database.prod_allocated_storage
  s3_bucket_name = "${var.environment}-oneflow-bucket"
}

provider "aws" {
  region = var.aws_region 
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

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public" {
  count          = var.subnet_count.public
  route_table_id = aws_route_table.oneflow_public_rt.id
  subnet_id      = aws_subnet.oneflow_public_subnet[count.index].id
}

# Creates the security group for the EC2 instance
resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.oneflow_vpc.id

  # Inbound rule for HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
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

# Create the EC2 instance
resource "aws_instance" "web" {
  associate_public_ip_address = true
  ami                         = var.settings.web_app.ami
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.oneflow_public_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]

  tags = {
    Name        = "oneflow_app"
    Environment = var.environment
  }
}

# Create the security group for the RDS instance
resource "aws_security_group" "oneflow_db_sg" {
  name   = "oneflow_db_sg"
  vpc_id = aws_vpc.oneflow_vpc.id

  # Inbound rule for MySQL traffic from the EC2 isntance
  ingress {
    from_port       = "3306"
    to_port         = "3306"
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
    Environment = var.environment
  }
}

# Create the S3 Bucket
resource "aws_s3_bucket" "oneflow_bucket" {
  bucket = local.s3_bucket_name

  tags = {
    Name        = "oneflow_bucket"
    Environment = var.environment
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "oneflow_bucket_public_access_block" {
  bucket = aws_s3_bucket.oneflow_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create a VPC endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.oneflow_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.oneflow_public_rt.id]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = ["s3:*"]
        Effect    = "Allow"
        Resource  = [
          aws_s3_bucket.oneflow_bucket.arn,
          "${aws_s3_bucket.oneflow_bucket.arn}/*"
        ]
        Principal = "*"
      }
    ]
  })

  tags = {
    Name = "oneflow_s3_endpoint"
  }
}

# Create a bucket policy that restricts access to the VPC endpoint
resource "aws_s3_bucket_policy" "oneflow_bucket_policy" {
  bucket = aws_s3_bucket.oneflow_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "RestrictedBucketPolicy",
    Statement = [
      {
        Sid       = "AllowVPCAccess",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          "${aws_s3_bucket.oneflow_bucket.arn}",
          "${aws_s3_bucket.oneflow_bucket.arn}/*"
        ],
        Condition = {
          StringEquals = {
            "aws:SourceVpc": "${aws_vpc.oneflow_vpc.id}"
          }
        }
      },
      {
        Sid       = "AllowTerraformServiceAccount",
        Effect    = "Allow",
        Principal = {
          AWS = "${data.aws_caller_identity.current.arn}"
        },
        Action    = "s3:*",
        Resource  = [
          "${aws_s3_bucket.oneflow_bucket.arn}",
          "${aws_s3_bucket.oneflow_bucket.arn}/*"
        ]
      },
      {
        Sid       = "DenyAllOtherAccess",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          "${aws_s3_bucket.oneflow_bucket.arn}",
          "${aws_s3_bucket.oneflow_bucket.arn}/*"
        ],
        Condition = {
          StringNotEquals = {
            "aws:SourceVpc": "${aws_vpc.oneflow_vpc.id}"
          },
          StringNotLike = {
            "aws:PrincipalArn": "${data.aws_caller_identity.current.arn}"
          }
        }
      }
    ]
  })
}