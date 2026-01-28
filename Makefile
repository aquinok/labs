SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ENV     ?= lab
REGION  ?= us-east-1
NODES   ?= 1
NODE    ?=

CERT_DIR ?= /etc/letsencrypt/live/aquinok.net
CERT_STAGE_DIR ?= $(HOME)/.labs-certs/aquinok.net

FULLCHAIN ?= $(CERT_DIR)/fullchain.pem
PRIVKEY ?= $(CERT_DIR)/privkey.pem

STAGED_FULLCHAIN ?= $(CERT_STAGE_DIR)/fullchain.pem
STAGED_PRIVKEY ?= $(CERT_STAGE_DIR)/privkey.pem

SUDO_SECRET_ID ?= lab/ubuntu-password

# Accept NODE as an alias for NODES (common typo)
ifneq ($(strip $(NODE)),)
  ifneq ($(origin NODES),command line)
    NODES := $(NODE)
  endif
endif
SSH_KEY ?= $(HOME)/.ssh/id_rsa

TF_BOOTSTRAP_DIR := terraform/bootstrap
TF_ENV_DIR       := terraform/envs/$(ENV)/$(REGION)
BACKEND_HCL      := $(TF_ENV_DIR)/backend.hcl

ANSIBLE_DIR    := ansible
INV_GEN_SCRIPT := scripts/generate-inventory.sh
CIS_RUNNER     := $(ANSIBLE_DIR)/run-cis-lab.sh


TLS_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/tls-install.yml
CERT_DIR     ?= /etc/letsencrypt/live/aquinok.net
FULLCHAIN    ?= $(CERT_DIR)/fullchain.pem
PRIVKEY      ?= $(CERT_DIR)/privkey.pem

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


.PHONY: bootstrap-up
bootstrap-up: bootstrap-init bootstrap-apply ## Bootstrap init + apply (one-time backend)
	@true

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
	 tmp="$$(mktemp)"; \
	 printf 'bucket = "%s"\ndynamodb_table = "%s"\nregion = "%s"\nkey = "%s"\nencrypt = true\n' \
		"$$bucket" "$$table" "$$region" "$$key" > "$$tmp"; \
	 if [[ -f "$(BACKEND_HCL)" ]] && cmp -s "$$tmp" "$(BACKEND_HCL)"; then \
		rm -f "$$tmp"; \
		echo "[+] backend.hcl unchanged ($(BACKEND_HCL))"; \
	 else \
		mv -f "$$tmp" "$(BACKEND_HCL)"; \
		echo "[+] Wrote $(BACKEND_HCL)"; \
	 fi

.PHONY: tf-init
tf-init: backend ## Terraform init (env) only if needed
	@cd "$(TF_ENV_DIR)" && { \
		set -euo pipefail; \
		STAMP=".terraform/backend.hcl.sha256"; \
		NEEDS_INIT=0; \
		if [[ ! -d ".terraform" ]]; then NEEDS_INIT=1; fi; \
		if [[ ! -f "$$STAMP" ]]; then NEEDS_INIT=1; fi; \
		CUR="$$(sha256sum backend.hcl | awk '{print $$1}')"; \
		OLD="$$( [[ -f "$$STAMP" ]] && cat "$$STAMP" || true )"; \
		if [[ "$$CUR" != "$$OLD" ]]; then NEEDS_INIT=1; fi; \
		if [[ "$$NEEDS_INIT" -eq 0 ]]; then \
			echo "[+] Terraform already initialized (backend unchanged) ($(TF_ENV_DIR))"; \
		else \
			echo "[+] Terraform initializing (or backend changed) ($(TF_ENV_DIR))"; \
			LOG="$$(mktemp)"; \
			if terraform init -input=false -no-color -reconfigure -backend-config="backend.hcl" >"$$LOG" 2>&1; then \
				echo "$$CUR" > "$$STAMP"; \
				rm -f "$$LOG"; \
			else \
				cat "$$LOG"; rm -f "$$LOG"; exit 1; \
			fi; \
		fi; \
	}

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

.PHONY: tls-stage
tls-stage: ## Stage TLS certs into $(CERT_STAGE_DIR) (local sudo required once)
	@echo "[+] Staging certs to $(CERT_STAGE_DIR)"
	@sudo mkdir -p "$(CERT_STAGE_DIR)"
	@sudo cp "$(FULLCHAIN)" "$(CERT_STAGE_DIR)/fullchain.pem"
	@sudo cp "$(PRIVKEY)"   "$(CERT_STAGE_DIR)/privkey.pem"
	@sudo chown -R "$(USER):$(USER)" "$(HOME)/.labs-certs"
	@chmod 700 "$(HOME)/.labs-certs" "$(CERT_STAGE_DIR)"
	@chmod 644 "$(CERT_STAGE_DIR)/fullchain.pem"
	@chmod 600 "$(CERT_STAGE_DIR)/privkey.pem"
	@echo "[+] Staged: $(CERT_STAGE_DIR)/fullchain.pem and privkey.pem"

.PHONY: cis
cis: inventory ## Run CIS hardening
	@TF_DIR="$(TF_ENV_DIR)" "$(CIS_RUNNER)"

.PHONY: tls-install
tls-install: inventory tls-stage ## Install wildcard TLS certs to all nodes (/opt/vault/tls)
	@test -f "$(STAGED_FULLCHAIN)" || (echo "ERROR: missing staged fullchain: $(STAGED_FULLCHAIN)" >&2; exit 1)
	@test -f "$(STAGED_PRIVKEY)"   || (echo "ERROR: missing staged privkey:   $(STAGED_PRIVKEY)" >&2; exit 1)
	@echo "[+] Pulling remote sudo password from Secrets Manager: $(SUDO_SECRET_ID)"
	@LAB_SUDO_PASS="$$(aws secretsmanager get-secret-value --secret-id "$(SUDO_SECRET_ID)" --query SecretString --output text)" ; \
	  test -n "$$LAB_SUDO_PASS" || (echo "ERROR: empty sudo password from secret $(SUDO_SECRET_ID)" >&2; exit 1) ; \
	  ANSIBLE_CONFIG="$(PWD)/$(ANSIBLE_DIR)/ansible.cfg" \
	  ANSIBLE_ROLES_PATH="$(PWD)/$(ANSIBLE_DIR)/roles:$(HOME)/.ansible/roles:/usr/share/ansible/roles" \
	  ansible-playbook -i "$(ANSIBLE_DIR)/inventories/$(ENV)/hosts.yml" "$(TLS_PLAYBOOK)" --limit vault \
	    -e ansible_become_password="$$LAB_SUDO_PASS" \
	    -e vault_tls_fullchain_src="$(STAGED_FULLCHAIN)" \
	    -e vault_tls_privkey_src="$(STAGED_PRIVKEY)"

.PHONY: clean-inventory
clean-inventory: ## Remove generated inventory
	@rm -f "$(ANSIBLE_DIR)/inventories/$(ENV)/hosts.yml"

.PHONY: clean-backend
clean-backend: ## Remove backend.hcl
	@rm -f "$(BACKEND_HCL)"
