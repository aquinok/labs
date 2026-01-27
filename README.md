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