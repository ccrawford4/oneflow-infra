# hs-cloud-interview

## Usage
1. Create a new file secrets.auto.tfvars
2. Paste in the following information:
```terraform
region = <the reigion you are deploying to e.g. us-east-2>
environment = <the enviornment e.g. dev, staging, or prod>
ami = <the amazon machine image ID>
db_username = <database username>
db_password = <database_password>
```

3.
```bash
terraform init
terraform plan
terraform apply
```

## To remove the infrastructure
```bash
terraform destroy
```