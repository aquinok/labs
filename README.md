# Lab Infrastructure

This repo provisions and hardens an Ubuntu 24.04 EC2 instance.

## Quick start

```bash
cd terraform/envs/lab/us-east-1
terraform init
terraform apply

cd ansible
./run-cis-lab.sh --tags level1-server

cd terraform/envs/lab/us-east-1
terraform destroy
```
