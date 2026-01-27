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
