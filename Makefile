SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Pick env + region when you run make:
#   make up ENV=lab REGION=us-east-1
ENV ?= lab
REGION ?= us-east-1

TF_BOOTSTRAP_DIR := terraform/bootstrap
TF_ENV_DIR := terraform/envs/$(ENV)/$(REGION)
TF_STATE_KEY := envs/$(ENV)/$(REGION)/terraform.tfstate

ANSIBLE_DIR := ansible
ANSIBLE_INV ?= inventories/$(ENV)/hosts.yml
ANSIBLE_PB  ?= playbooks/ubuntu24-cis.yml
ANSIBLE_TAGS ?= level1-server

.PHONY: help bootstrap up cis down nuke backend-info

help:
	@echo ""
	@echo "Targets:"
	@echo "  make bootstrap                Create S3 backend + DynamoDB lock (one-time)"
	@echo "  make up ENV=lab REGION=us-east-1    Terraform apply for env/region"
	@echo "  make cis ENV=lab              Run CIS playbook using run-cis-lab.sh"
	@echo "  make down ENV=lab REGION=us-east-1  Terraform destroy for env/region"
	@echo "  make nuke                     Destroy env (default lab/us-east-1) + backend"
	@echo ""
	@echo "Notes:"
	@echo "  - Backend key is: $(TF_STATE_KEY)"
	@echo "  - ENV defaults to 'lab', REGION defaults to 'us-east-1'"
	@echo ""

bootstrap:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	terraform init; \
	terraform apply -auto-approve

backend-info:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	terraform output

# Terraform init configured at runtime using outputs from bootstrap
up:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	B="$$(terraform output -raw backend_bucket_name)"; \
	T="$$(terraform output -raw backend_dynamodb_table)"; \
	R="$$(terraform output -raw backend_region)"; \
	echo "Using backend bucket=$$B table=$$T region=$$R key=$(TF_STATE_KEY)"; \
	cd - >/dev/null; \
	cd "$(TF_ENV_DIR)"; \
	terraform init -reconfigure \
	  -backend-config="bucket=$$B" \
	  -backend-config="dynamodb_table=$$T" \
	  -backend-config="region=$$R" \
	  -backend-config="key=$(TF_STATE_KEY)" \
	  -backend-config="encrypt=true"; \
	terraform apply -auto-approve

down:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	B="$$(terraform output -raw backend_bucket_name)"; \
	T="$$(terraform output -raw backend_dynamodb_table)"; \
	R="$$(terraform output -raw backend_region)"; \
	cd - >/dev/null; \
	cd "$(TF_ENV_DIR)"; \
	terraform init -reconfigure \
	  -backend-config="bucket=$$B" \
	  -backend-config="dynamodb_table=$$T" \
	  -backend-config="region=$$R" \
	  -backend-config="key=$(TF_STATE_KEY)" \
	  -backend-config="encrypt=true"; \
	terraform destroy -auto-approve

cis:
	@set -euo pipefail; \
	cd "$(ANSIBLE_DIR)"; \
	./run-cis-lab.sh --tags "$(ANSIBLE_TAGS)"

# WARNING: nuke removes backend infra too (S3 bucket + DDB lock table)
nuke: down
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	terraform destroy -auto-approve
