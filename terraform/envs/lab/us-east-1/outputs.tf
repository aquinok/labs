output "public_ips" {
  value = module.ec2.public_ips
}

output "ssh_commands" {
  value = [
    for ip in module.ec2.public_ips :
    "ssh -i ~/.ssh/id_rsa ubuntu@${ip}"
  ]
}

output "instance_public_ips" {
  value = module.ec2.public_ips
}

output "instance_names" {
  value = module.ec2.names
}

output "ssh_commands_by_name" {
  value = {
    for idx, ip in module.ec2.public_ips :
    format("vault-%02d", idx+1) => "ssh -i ~/.ssh/id_rsa ubuntu@${ip}"
  }
}