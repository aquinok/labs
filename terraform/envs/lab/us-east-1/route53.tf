variable "domain_name" {
  type        = string
  description = "Existing Route53 public hosted zone name (e.g. aquinok.net)"
  default     = "aquinok.net"
}

# Look up the existing public hosted zone; we are NOT creating a new zone.
data "aws_route53_zone" "public" {
  name         = "${var.domain_name}."
  private_zone = false
}

locals {
  # Creates:
  #   lab-01.aquinok.net -> <ip>
  #   lab-02.aquinok.net -> <ip>
  #   ...
  node_a_records = {
    for idx, ip in module.ec2.public_ips :
    "${module.ec2.names[idx]}.${var.domain_name}" => ip
  }
}
 
resource "aws_route53_record" "nodes_a" {
  for_each = local.node_a_records

  zone_id = data.aws_route53_zone.public.zone_id
  name    = each.key
  type    = "A"
  ttl     = 60
  records = [each.value]
}

# Optional: one service name that round-robins to all nodes (fine for lab)
resource "aws_route53_record" "vault_rr" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = "vault.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = module.ec2.public_ips
}

resource "aws_route53_record" "zabbix_a" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = "zabbix.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [module.zabbix.public_ips[0]]
}

output "node_fqdns" {
  value = [for n in module.ec2.names : "${n}.${var.domain_name}"]
}

output "vault_fqdn" {
  value = "vault.${var.domain_name}"
}

output "zabbix_fqdn" {
  value = "zabbix.${var.domain_name}"
}
