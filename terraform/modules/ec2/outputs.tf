output "public_ips" {
  value = [for i in aws_instance.this : i.public_ip]
}

output "public_dns" {
  value = [for i in aws_instance.this : i.public_dns]
}

output "instance_ids" {
  value = [for i in aws_instance.this : i.id]
}

output "names" {
  value = [for i in aws_instance.this : i.tags["Name"]]
}

output "key_name" {
  value = aws_key_pair.this.key_name
}
