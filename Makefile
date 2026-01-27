SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ENV     ?= lab
REGION  ?= us-east-1
NODES   ?= 1
SSH_KEY ?= $(HOME)/.ssh/id_rsa

TF_BOOTSTRAP_DIR := terraform/bootstrap
TF_ENV_DIR       := terraform/envs/$(ENV)/$(REGION)
BACKEND_HCL      := $(TF_ENV_DIR)/backend.hcl

ANSIBLE_DIR    := ansible
INV_GEN_SCRIPT := scripts/generate-inventory.sh
CIS_RUNNER     := $(ANSIBLE_DIR)/run-cis-lab.sh

define tf_bootstrap
	cd "$(TF_BOOTSTRAP_DIR)" && terraform $(1)
endef

define tf_env
	cd "$(TF_ENV_DIR)" && terraform $(1)
endef

.PHONY: help
help: ## Show help
	@echo ""
	@echo "Labs automation (Terraform + Ansible)"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [ENV=lab] [REGION=us-east-1] [NODES=1]"
	@echo ""
	@awk 'BEGIN {FS=":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

.PHONY: bootstrap-init
bootstrap-init: ## Terraform init (bootstrap)
	@$(call tf_bootstrap,init)

.PHONY: bootstrap-apply
bootstrap-apply: ## Terraform apply (bootstrap)
	@$(call tf_bootstrap,apply)

.PHONY: bootstrap-destroy
bootstrap-destroy: ## Terraform destroy (bootstrap)
	@$(call tf_bootstrap,destroy)

.PHONY: backend
backend: ## Generate backend.hcl from bootstrap outputs
	@mkdir -p "$(TF_ENV_DIR)"
	@bucket="$$(cd "$(TF_BOOTSTRAP_DIR)" && terraform output -raw backend_bucket_name)"; \
	table="$$(cd "$(TF_BOOTSTRAP_DIR)" && terraform output -raw backend_dynamodb_table)"; \
	region="$$(cd "$(TF_BOOTSTRAP_DIR)" && terraform output -raw backend_region)"; \
	key="labs/$(ENV)/$(REGION)/terraform.tfstate"; \
	printf "bucket = \"%s\"\ndynamodb_table = \"%s\"\nregion = \"%s\"\nkey = \"%s\"\nencrypt = true\n" \
		"$$bucket" "$$table" "$$region" "$$key" > "$(BACKEND_HCL)"
	@echo "✔ Wrote $(BACKEND_HCL)"

.PHONY: tf-init
tf-init: backend ## Terraform init (env)
	@cd "$(TF_ENV_DIR)" && terraform init -reconfigure -backend-config="backend.hcl"

.PHONY: plan
plan: tf-init ## Terraform plan
	@$(call tf_env,plan -var="node_count=$(NODES)")

.PHONY: up
up: tf-init ## Terraform apply
	@$(call tf_env,apply -var="node_count=$(NODES)")

.PHONY: down
down: tf-init ## Terraform destroy
	@$(call tf_env,destroy -var="node_count=$(NODES)")

.PHONY: output
output: tf-init ## Terraform output
	@$(call tf_env,output)

.PHONY: inventory
inventory: tf-init ## Generate Ansible inventory
	@TF_DIR="$(TF_ENV_DIR)" SSH_KEY="$(SSH_KEY)" "$(INV_GEN_SCRIPT)"

.PHONY: cis
cis: inventory ## Run CIS hardening
	@TF_DIR="$(TF_ENV_DIR)" "$(CIS_RUNNER)"

.PHONY: clean-inventory
clean-inventory: ## Remove generated inventory
	@rm -f "$(ANSIBLE_DIR)/inventories/$(ENV)/hosts.yml"

.PHONY: clean-backend
clean-backend: ## Remove backend.hcl
	@rm -f "$(BACKEND_HCL)"
