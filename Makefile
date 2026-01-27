# =========================
# Labs repo Makefile
# Terraform + Ansible automation
# =========================

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ---- Repo paths (relative to repo root) ----
TF_ENV_DIR ?= terraform/envs/lab/us-east-1
TF_BOOTSTRAP_DIR ?= terraform/bootstrap
ANSIBLE_DIR ?= ansible
INV_GEN_SCRIPT ?= scripts/generate-inventory.sh
CIS_RUNNER ?= $(ANSIBLE_DIR)/run-cis-lab.sh

# ---- Common knobs ----
ENV ?= lab
REGION ?= us-east-1

# SSH key used by generated inventory (can override)
SSH_KEY ?= $(HOME)/.ssh/id_rsa

# Optional: backend config file path for terraform init (if you use one)
# Example usage:
#   make tf-init BACKEND_CONFIG=backend.hcl
BACKEND_CONFIG ?=

# ---- Utilities ----
define _tf_cmd
	cd "$(TF_ENV_DIR)" && terraform $(1)
endef

define _tf_bootstrap_cmd
	cd "$(TF_BOOTSTRAP_DIR)" && terraform $(1)
endef

# =========================
# Help
# =========================
.PHONY: help
help: ## Show this help (targets + descriptions)
	@echo ""
	@echo "Labs automation (Terraform + Ansible)"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [ENV=lab] [REGION=us-east-1] [TF_ENV_DIR=...] [SSH_KEY=...]"
	@echo ""
	@echo "Key paths:"
	@echo "  TF_ENV_DIR        = $(TF_ENV_DIR)"
	@echo "  TF_BOOTSTRAP_DIR  = $(TF_BOOTSTRAP_DIR)"
	@echo "  INV_GEN_SCRIPT    = $(INV_GEN_SCRIPT)"
	@echo "  CIS_RUNNER        = $(CIS_RUNNER)"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@echo ""

# =========================
# Terraform (bootstrap)
# =========================
.PHONY: bootstrap-init
bootstrap-init: ## Terraform init in terraform/bootstrap
	@$(call _tf_bootstrap_cmd,init)

.PHONY: bootstrap-apply
bootstrap-apply: ## Terraform apply in terraform/bootstrap (state bucket/lock, etc.)
	@$(call _tf_bootstrap_cmd,apply)

.PHONY: bootstrap-destroy
bootstrap-destroy: ## Terraform destroy in terraform/bootstrap
	@$(call _tf_bootstrap_cmd,destroy)

# =========================
# Terraform (env)
# =========================
.PHONY: tf-init
tf-init: ## Terraform init in TF_ENV_DIR (optionally BACKEND_CONFIG=backend.hcl)
	@if [[ -n "$(BACKEND_CONFIG)" ]]; then \
		(cd "$(TF_ENV_DIR)" && terraform init -backend-config="$(BACKEND_CONFIG)"); \
	else \
		$(call _tf_cmd,init); \
	fi

.PHONY: plan
plan: ## Terraform plan in TF_ENV_DIR
	@$(call _tf_cmd,plan)

.PHONY: up
up: ## Terraform apply in TF_ENV_DIR (bring lab up)
	@$(call _tf_cmd,apply)

.PHONY: down
down: ## Terraform destroy in TF_ENV_DIR (tear lab down)
	@$(call _tf_cmd,destroy)

.PHONY: output
output: ## Terraform output in TF_ENV_DIR
	@$(call _tf_cmd,output)

# =========================
# Inventory generation (NEW)
# =========================
.PHONY: inventory
inventory: ## Generate ansible inventory from Terraform output (writes ansible/inventories/lab/hosts.yml)
	@TF_DIR="$(TF_ENV_DIR)" SSH_KEY="$(SSH_KEY)" "$(INV_GEN_SCRIPT)"

# =========================
# Ansible / CIS
# =========================
.PHONY: cis
cis: inventory ## Run CIS lockdown playbook (auto-generates inventory first)
	@TF_DIR="$(TF_ENV_DIR)" "$(CIS_RUNNER)"

# =========================
# Quality-of-life helpers
# =========================
.PHONY: clean-inventory
clean-inventory: ## Remove generated inventory file (ansible/inventories/lab/hosts.yml)
	@rm -f "$(ANSIBLE_DIR)/inventories/$(ENV)/hosts.yml"
	@echo "✔ Removed $(ANSIBLE_DIR)/inventories/$(ENV)/hosts.yml"

.PHONY: show-vars
show-vars: ## Print the resolved variables this Makefile is using
	@echo "ENV              = $(ENV)"
	@echo "REGION           = $(REGION)"
	@echo "TF_ENV_DIR       = $(TF_ENV_DIR)"
	@echo "TF_BOOTSTRAP_DIR = $(TF_BOOTSTRAP_DIR)"
	@echo "SSH_KEY          = $(SSH_KEY)"
	@echo "BACKEND_CONFIG   = $(BACKEND_CONFIG)"
	@echo "INV_GEN_SCRIPT   = $(INV_GEN_SCRIPT)"
	@echo "CIS_RUNNER       = $(CIS_RUNNER)"
