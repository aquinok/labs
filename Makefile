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

BACKEND_ENV := .backend.env

.PHONY: help bootstrap up cis down nuke backend-info

help:
	@echo ""
	@echo "Targets:"
	@echo "  make bootstrap"
	@echo "      Create S3 backend + DynamoDB lock (one-time, local state)"
	@echo ""
	@echo "  make up ENV=lab REGION=us-east-1"
	@echo "      Terraform apply for env/region using remote S3 backend"
	@echo ""
	@echo "  make cis ENV=lab"
	@echo "      Generate inventory from Terraform outputs and run CIS hardening"
	@echo ""
	@echo "  make down ENV=lab REGION=us-east-1"
	@echo "      Terraform destroy for env/region (leaves backend intact)"
	@echo ""
	@echo "  make nuke"
	@echo "      Destroy env AND backend:"
	@echo "        - terraform destroy (env)"
	@echo "        - terraform destroy (bootstrap)"
	@echo "        - force-purge all S3 state versions"
	@echo "        - delete S3 bucket and DynamoDB lock table"
	@echo ""
	@echo "Optional:"
	@echo "  make purge-backend"
	@echo "      Force-delete all object versions and delete markers in tfstate bucket"
	@echo ""
	@echo "Defaults:"
	@echo "  ENV    = lab"
	@echo "  REGION = us-east-1"
	@echo ""

bootstrap:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	terraform init; \
	terraform apply -auto-approve; \
	cd - >/dev/null; \
	./scripts/save_backend_env.sh "$(TF_BOOTSTRAP_DIR)" ".backend.env"

backend-info:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	terraform output

# Terraform init configured at runtime using outputs from bootstrap
up:
	@set -euo pipefail; \
	test -f "$(BACKEND_ENV)" || (echo "Missing $(BACKEND_ENV). Run: make bootstrap" && exit 1); \
	source "$(BACKEND_ENV)"; \
	echo "Using backend bucket=$$BACKEND_BUCKET region=$$BACKEND_REGION key=$(TF_STATE_KEY)"; \
	cd "$(TF_ENV_DIR)"; \
	terraform init -reconfigure \
	  -backend-config="bucket=$$BACKEND_BUCKET" \
	  -backend-config="region=$$BACKEND_REGION" \
	  -backend-config="key=$(TF_STATE_KEY)" \
	  -backend-config="encrypt=true" \
	  -backend-config="use_lockfile=true"; \
	terraform apply -auto-approve

down:
	@set -euo pipefail; \
	test -f "$(BACKEND_ENV)" || (echo "Missing $(BACKEND_ENV). If backend already nuked, skip down." && exit 1); \
	source "$(BACKEND_ENV)"; \
	cd "$(TF_ENV_DIR)"; \
	terraform init -reconfigure \
	  -backend-config="bucket=$$BACKEND_BUCKET" \
	  -backend-config="region=$$BACKEND_REGION" \
	  -backend-config="key=$(TF_STATE_KEY)" \
	  -backend-config="encrypt=true" \
	  -backend-config="use_lockfile=true"; \
	terraform destroy -auto-approve

cis:
	@set -euo pipefail; \
	cd "$(ANSIBLE_DIR)"; \
	./run-cis-lab.sh --tags "$(ANSIBLE_TAGS)"

purge-backend:
	@set -euo pipefail; \
	cd "$(TF_BOOTSTRAP_DIR)"; \
	B="$$(terraform output -raw backend_bucket_name)"; \
	cd - >/dev/null; \
	./scripts/purge_tfstate_bucket.sh "$$B"; \
	aws s3 rb "s3://$$B"

# WARNING: nuke removes backend infra too (S3 bucket + DDB lock table)
nuke:
	@set -euo pipefail; \
	if test -f "$(BACKEND_ENV)"; then \
	  source "$(BACKEND_ENV)"; \
	else \
	  echo "No $(BACKEND_ENV) found. If env is already gone, continuing..."; \
	  BACKEND_BUCKET=""; \
	fi; \
	$(MAKE) down || true; \
	echo "Destroying bootstrap..."; \
	cd "$(TF_BOOTSTRAP_DIR)" && terraform destroy -auto-approve || true; \
	if [[ -n "$$BACKEND_BUCKET" ]]; then \
	  echo "Forcing purge + delete of versioned tfstate bucket $$BACKEND_BUCKET"; \
	  cd - >/dev/null; \
	  ./scripts/purge_tfstate_bucket.sh "$$BACKEND_BUCKET" || true; \
	  aws s3 rb "s3://$$BACKEND_BUCKET" || true; \
	fi; \
	rm -f "$(BACKEND_ENV)" || true
