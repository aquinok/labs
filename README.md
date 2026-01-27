# Labs -- Terraform + Ansible (CIS Hardened)

This repository provisions a **repeatable AWS lab environment** using
Terraform, applies **CIS hardening** with Ansible, and tears everything
down cleanly.\
The **Makefile is the single interface** --- no manual Terraform or
Ansible commands required.

------------------------------------------------------------------------

## Prerequisites

You must have the following installed and available in your PATH:

-   Terraform
-   Ansible
-   AWS CLI v2
-   SSH client
-   Python 3

Verify:

``` bash
terraform version
ansible --version
aws --version
ssh -V
python3 --version
```

------------------------------------------------------------------------

## AWS Authentication

You must be authenticated to AWS (env vars, profile, or SSO).

Verify:

``` bash
aws sts get-caller-identity
```

------------------------------------------------------------------------

## SSH Key

By default the lab expects:

-   `~/.ssh/id_rsa`
-   `~/.ssh/id_rsa.pub`

If you use a different key, override it with `SSH_KEY` when running Make
targets.

------------------------------------------------------------------------

## One-Time Setup (per AWS account)

This creates the **remote Terraform backend** (S3 bucket + DynamoDB lock
table).\
You only do this once unless you intentionally destroy it.

``` bash
make bootstrap-init
make bootstrap-apply
```

------------------------------------------------------------------------

## Bring Up the Lab (N nodes)

This initializes Terraform, generates backend configuration
automatically, and provisions EC2 instances.

``` bash
make tf-init
make up NODES=3
```

Defaults: - ENV = lab - REGION = us-east-1 - NODES = 1 (override as
shown above)

------------------------------------------------------------------------

## Generate Ansible Inventory

Inventory is **derived from Terraform outputs** (never edited manually).

``` bash
make inventory
```

If you use a non-default SSH key:

``` bash
make inventory SSH_KEY="$HOME/.ssh/mykey"
```

This generates:

    ansible/inventories/lab/hosts.yml

------------------------------------------------------------------------

## Apply CIS Hardening

Runs the CIS lockdown playbook against all nodes.

-   Terraform generated a sudo password
-   Password is stored in AWS Secrets Manager
-   Ansible retrieves it at runtime for `become`

``` bash
make cis
```

This will: - Ensure Terraform is initialized - Generate inventory - Run
CIS hardening across all nodes

------------------------------------------------------------------------

## Tear Down the Lab

Destroy all EC2 resources (remote state remains intact).

``` bash
make down
```

Optional cleanup of generated files:

``` bash
make clean-inventory
make clean-backend
```

------------------------------------------------------------------------

## Full Happy Path (3-node lab)

``` bash
make bootstrap-init
make bootstrap-apply

make tf-init
make up NODES=3
make cis
make down
```

------------------------------------------------------------------------

## Important Notes

### Do NOT routinely destroy bootstrap

`make bootstrap-destroy` deletes the Terraform backend itself.\
Only run this if you are intentionally resetting everything.

### Inventory and backend files are generated

These files are intentionally **not committed to git**:

-   `terraform/envs/**/backend.hcl`
-   `ansible/inventories/**/hosts.yml`

------------------------------------------------------------------------

## Troubleshooting

### Backend errors

If Terraform reports backend changes:

``` bash
make tf-init
```

The Makefile automatically regenerates backend config and reinitializes
safely.

### SSH failures

-   Confirm your IP is allowed in `allowed_ssh_cidrs`
-   Confirm the SSH key path is correct

### CIS fails on sudo

Ensure: - AWS identity can read Secrets Manager -
`secretsmanager:GetSecretValue` - `kms:Decrypt` (if using a CMK)

------------------------------------------------------------------------

## Design Principles

-   Terraform is the source of truth
-   Ansible consumes Terraform outputs
-   Inventory is derived, never hand-edited
-   CIS requires real sudo passwords (no NOPASSWD shortcuts)
-   Everything is reproducible via Make

------------------------------------------------------------------------

## Next Steps

-   Add private networking
-   Convert public IPs → private IPs
-   Build Vault cluster (Raft)
-   Add TLS + retry_join