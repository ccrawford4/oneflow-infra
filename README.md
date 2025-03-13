# hs-cloud-interview

## Usage
1. Create a new file <file-name>.auto.tfvars
2. Paste in the following information:
```terraform
region = <the reigion you are deploying to e.g. us-east-2>
environment = <the enviornment e.g. dev, staging, or prod>
ami = <the amazon machine image ID>
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