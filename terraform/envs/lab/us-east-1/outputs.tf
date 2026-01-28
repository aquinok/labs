# ----------------------------
# Core instance data
# ----------------------------

output "instance_names" {
  description = "Names of EC2 instances in the lab"
  value       = module.ec2.names
}

output "public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = module.ec2.public_ips
}

output "private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = module.ec2.private_ips
}

output "zabbix_instance_name" {
  description = "Name of the Zabbix instance"
  value       = module.zabbix.names[0]
}

output "zabbix_public_ip" {
  description = "Public IP of the Zabbix instance"
  value       = module.zabbix.public_ips[0]
}

output "zabbix_private_ip" {
  description = "Private IP of the Zabbix instance"
  value       = module.zabbix.private_ips[0]
}

# ----------------------------
# Convenience outputs (human)
# ----------------------------

output "ssh_commands_by_name" {
  description = "SSH commands keyed by instance name"
  value = {
    for idx, ip in module.ec2.public_ips :
    module.ec2.names[idx] => "ssh -i ~/.ssh/id_rsa ubuntu@${ip}"
  }
}

output "zabbix_ssh_command" {
  description = "SSH command for the Zabbix node"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${module.zabbix.public_ips[0]}"
}
