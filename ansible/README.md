# labs/ansible

This repo contains playbooks + inventories for my lab environment (WSL2 + AWS).
Primary use case: harden Ubuntu 24.04 using the CIS role from ansible-lockdown.

## Prereqs

- Ubuntu 24.04 (WSL2 is fine)
- `ansible` installed (>= 2.12; I'm using 2.16+)
- AWS CLI configured (for retrieving the sudo password from Secrets Manager)
- SSH access to the target instance

### Install Ansible (Ubuntu)
```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```


## TLS Install (wildcard *.aquinok.net)

This installs `fullchain.pem` and `privkey.pem` **from the control machine**
to all lab nodes under `/opt/vault/tls/`.

Default source paths (override via extra-vars):

- `/etc/letsencrypt/live/aquinok.net/fullchain.pem`
- `/etc/letsencrypt/live/aquinok.net/privkey.pem`

Run via Make:

```bash
make tls-install
```

Or directly:

```bash
ansible-playbook -i ansible/inventories/lab/hosts.yml ansible/playbooks/tls-install.yml \
  -e vault_tls_fullchain_src=/path/to/fullchain.pem \
  -e vault_tls_privkey_src=/path/to/privkey.pem
```
