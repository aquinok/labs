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
