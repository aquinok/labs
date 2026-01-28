output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "cidr_block" {
  value = aws_vpc.this.cidr_block
}

