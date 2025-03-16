# OneFlow Infrastructure

## Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/install) >= v1.10.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) >= 2.18.5
- [MySQL CLI](https://dev.mysql.com/doc/mysql-getting-started/en/) >= 9.2.0
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Installation

1. Clone the repository
   ```bash
   # Using HTTPS
   git clone https://github.com/ccrawford4/hs-cloud-interview.git
   
   # Or using SSH
   git clone git@github.com:ccrawford4/hs-cloud-interview.git
   ```

2. Navigate to the repository directory
   ```bash
   cd hs-cloud-interview
   ```

## Environment Configuration

1. Create your `secrets.auto.tfvars` file
   ```bash
   cp secrets.auto.tfvars.example secrets.auto.tfvars
   ```

2. Edit the `secrets.auto.tfvars` file with your configuration values:
   ```terraform
   aws_region = "<aws region>"
   environment = "<environment name>"  # dev or prod
   aws_account_id = "<aws account id>"
   db_username = "<database username>"
   db_password = "<database password>"
   db_name = "<database name>"
   db_port = <database port>
   ```

3. Configure AWS CLI with the Terraform user credentials
   ```bash
   aws configure --profile terraform
   ```
   > Note: Credentials will be provided by OneFlow admin

## Infrastructure Deployment

Deploy the infrastructure:
```bash
export AWS_PROFILE=terraform
terraform init
terraform plan
terraform apply
```

## Testing

### EC2 Instance

1. Copy the `instance_public_dns` output from the terraform apply step
2. Test HTTP access (should be blocked)
   ```bash
   curl http://<instance_public_dns>
   ```
   The request should time out after ~5 seconds, confirming EC2 is blocking insecure public connections.

3. Test HTTPS access
   ```bash
   curl https://<instance_public_dns>
   ```
   You should receive a connection error indicating the EC2 instance accepts HTTPS connections but nothing is listening on port 443:
   ```
   curl: (7) Failed to connect to <instance_public_dns> port 443: Connection refused
   ```

### MySQL RDS

#### Public Access Check
1. Copy the `rds_endpoint` from the terraform apply output
2. Try connecting from your local machine
   ```bash
   mysql -u <db_username> --password=<db_password> -h <rds_endpoint without port>
   ```
   The request should time out, confirming your RDS instance blocks connections from outside the VPC.

#### Private Access Check
1. Note the `key_name` and `instance_public_dns` from the terraform output
2. Run the connection script
   ```bash
   ./download-key.sh <key_name> <instance_public_dns> <aws region>
   ```
3. When prompted "Connect now? (y/n)", type `y` and press Enter
4. From the EC2 instance, connect to the RDS database
   ```bash
   mysql -u <db_username> --password=<db_password> -h <rds_endpoint without port>
   ```
5. Verify you can access your database with:
   ```sql
   SHOW DATABASES;
   ```
   Your database should appear in the list.

### S3 Bucket

1. Copy the `s3_bucket_name` from the terraform output
2. Test public access using a non-terraform AWS profile
   ```bash
   AWS_PROFILE=default aws s3 ls s3://<s3_bucket_name>/
   ```
   You should receive an "AccessDenied" error, confirming the bucket blocks public access.

3. Test private access from the EC2 instance
   - Connect to the EC2 instance using `download-key.sh` as shown above
   - Run the S3 list command from the EC2 instance
     ```bash
     aws s3 ls s3://<s3_bucket_name>/
     ```
   - A successful response confirms your EC2 has proper permissions to access the S3 bucket.
