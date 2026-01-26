output "public_ip" {
  value = module.ec2.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${module.ec2.public_ip}"
}
