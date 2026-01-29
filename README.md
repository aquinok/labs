# Labs Infrastructure & Observability

This repository provides a **Makefile-driven workflow** for provisioning infrastructure, configuring hosts, and deploying a production-grade **Zabbix observability stack**.

The Makefile is the primary interface. If you remember nothing else:

> **Run things via `make`. Do not run Terraform or Ansible directly unless debugging.**

---

## Quick start (happy path)

```bash
# One-time: install Ansible roles & collections
make galaxy

# Bootstrap Terraform backend (one-time per account/region)
make bootstrap-up

# Provision infra
make up

# Install Zabbix (server + web + DB via Docker)
make zabbix-install

# Install Zabbix Agent2 on monitored nodes
make zabbix-agent

# Register hosts in Zabbix via API
make zabbix-register
```

Or, end-to-end:

```bash
make observability
```

---

## Makefile concepts

### Environment selection

The workflow is parameterized via variables:

* `ENV` – environment name (default: `lab`)
* `REGION` – cloud region (default: `us-east-1`)
* `NODES` – number of nodes to provision (default: `1`)

Example:

```bash
make up ENV=sandbox REGION=us-west-2 NODES=3
```

---

#### (Pre-flight) CIS hardening

```bash
make cis
```

What this does:

* Applies CIS-aligned baseline hardening to hosts
* Safe to re-run (idempotent)

---

## Zabbix observability workflow

### 1. Zabbix install (server-side)

```bash
make zabbix-install
```

What this does:

* Targets the `zabbix` host group
* Deploys Zabbix Server, Web UI, DB, and nginx reverse proxy via Docker
* Configures TLS using a wildcard Let’s Encrypt cert
* Pulls the Zabbix admin password from AWS Secrets Manager

After completion:

* UI is available at:

  **[https://zabbix.aquinok.net](https://zabbix.aquinok.net)**

---

### 2. Zabbix Agent2 install (node-side)

```bash
make zabbix-agent
```

What this does:

* Installs **Zabbix Agent2** via Ansible
* Configures agents for **active checks**
* Starts and enables the service

- [x] Agents running at this point is expected
- [ ] Hosts will *not* appear in the UI yet

This is normal.

---

### 3. Zabbix host registration (API-side)

```bash
make zabbix-register
```

What this does:

* Authenticates to the Zabbix API
* Ensures required host groups exist
* Creates or updates hosts
* Links templates

**Important constraint**

> The hostname **must exactly match** the agent configuration, or registration will silently fail.

---

### 4. Full observability pipeline

```bash
make observability
```

Equivalent to:

```bash
make zabbix-install zabbix-agent zabbix-register
```

---

## TLS handling

TLS is handled explicitly and safely.

### Stage certs locally (one-time per machine)

```bash
make tls-stage
```

This:

* Copies wildcard certs from `/etc/letsencrypt/live/aquinok.net`
* Stages them into `~/.labs-certs/aquinok.net`
* Fixes ownership and permissions

### Install certs on nodes

```bash
make tls-install
```

---

## Terraform lifecycle

### Bootstrap (one-time)

```bash
make bootstrap-up
```

Creates:

* Remote state S3 bucket
* DynamoDB state lock table

### Environment lifecycle

```bash
make plan
make up
make down
```

Terraform init is **idempotent and guarded**. It will only re-run when the backend changes.

---

## Inventory generation

```bash
make inventory
```

* Generates Ansible inventory from Terraform outputs
* Output location:

  `ansible/inventories/<ENV>/hosts.yml`

This is automatically run by most targets.

---

## Ansible dependencies

Install all required roles and collections with:

```bash
make galaxy
```

This installs:

* Roles
* Collections (including `community.zabbix`)

Do not skip this step.

---

## Help

List all available targets:

```bash
make help
```