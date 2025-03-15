# OneFlow infrastructure

## Prerequisites
1. [terraform](https://developer.hashicorp.com/terraform/install) >= v1.10.5
2. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) >= 2.18.5
3. [mysql cli](https://dev.mysql.com/doc/mysql-getting-started/en/) >= 9.2.0
4. [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Getting started
### Installation
1. Clone the repository
```bash
# If using HTTPS
git clone https://github.com/ccrawford4/hs-cloud-interview.git

# If using SSH
git clone git@github.com:ccrawford4/hs-cloud-interview.git
```
2. Naviate to the source directory
```bash
cd ../[directory path to where the repository was cloned]/hs-cloud-interview
```

### Enviornment Configuration
1. Create a new `secrets.auto.tfvars` file
```bash
cp secrets.auto.tfvars.example secrets.auto.tfvars
```
2. Change the fields underneath the `TODO` comment
```terraform
aws_region = "<aws region>"
enviornment = "<enviornment name>" # dev or prod
aws_account_id = "<aws account id>"
db_username = "<the database username>"
db_password = "<the database password>"
```
3. Configure your aws cli with the terraform user
```bash
aws configure --profile terrafrom
```
a. Credentials provided by OneFlow admin

### Infrastructure Deployment
1. Run the following commands
```bash
terraform init
terraform plan
AWS_PROFILE=terraform terraform apply
```

### Testing
#### EC2
1. Copy the `instance_public_dns` output from the `terraform apply` step
2. Attempt a curl request using HTTP
```bash
curl http://<instance_public_dns>
```
The request should hang. If you don't receive a response in ~5 seconds or less, then your EC2 is successfully blocking insecure public connections.

3. Attempt a curl request using HTTPS
```bash
curl https://<instance_public_dns>
```
Since there is no process running on port 443 you should get an output like so:
```bash
curl: (7) Failed to connect to <instance_public_dns> port 443 after 66 ms: Couldn't connect to server
```
This means that your EC2 is successfully accepting secure HTTPS connections over port 443

#### MySQL RDS
##### Public access check
1. Copy the `rds_endpoint` output from the `terraform apply` step
2. Attempt to connect to the MySQL instance using the following command:
```bash
mysql -u <db_username> --password=<db_password> -h </db><rds_endpoint> product
```
Verify that you are unable to connect since the RDS instance should block connections from outside of the VPC

##### Private access check
1. Take note of the `key_name` from the `terraform apply` step
2. Take note of the `instance_public_dns` from the `terraform apply` step
3. Run the `download-key.sh` script
```bash
./download-key.sh <key_name> <instance_public_dns>
```
When prompted like so: `Connect now? (y/n)` type 'y' and then press the enter key
4. 

