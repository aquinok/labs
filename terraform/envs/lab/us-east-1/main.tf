module "vpc" {
  source             = "../../../modules/vpc"
  name               = var.name
  cidr_block         = "10.10.0.0/16"
  public_subnet_cidr = "10.10.1.0/24"
  az                 = var.az
  tags               = var.tags
}

module "sg" {
  source            = "../../../modules/security-groups"
  name              = var.name
  vpc_id            = module.vpc.vpc_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  tags              = var.tags
}

module "ec2" {
  source                 = "../../../modules/ec2"
  name                   = var.name
  node_count             = var.node_count
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [module.sg.ssh_sg_id]
  public_key             = file(pathexpand(var.public_key_path))

user_data = templatefile("${path.module}/user_data.yaml.tftpl", {
  ubuntu_password = random_password.ubuntu.result
  ssh_public_key  = chomp(file(pathexpand(var.public_key_path)))
})

  tags = var.tags
}

# Zabbix (monitoring) node
resource "aws_security_group" "zabbix" {
  name        = "${var.name}-zabbix"
  description = "Zabbix web + server ports"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Zabbix Web (HTTP)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "Zabbix Web (HTTPS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "Zabbix agent (passive checks)"
    from_port   = 10050
    to_port     = 10050
    protocol    = "tcp"
    cidr_blocks = [module.vpc.cidr_block]
  }

  ingress {
    description = "Zabbix server (trapper)"
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = [module.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-zabbix"
  })
}

module "zabbix" {
  source                 = "../../../modules/ec2"
  name                   = "${var.name}-zbx"
  node_count             = 1
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [module.sg.ssh_sg_id, aws_security_group.zabbix.id]
  public_key             = file(pathexpand(var.public_key_path))

	# Keep it simple for lab: same cloud-init user/password as other nodes
	user_data = templatefile("${path.module}/user_data.yaml.tftpl", {
	  ubuntu_password = random_password.ubuntu.result
	  ssh_public_key  = chomp(file(pathexpand(var.public_key_path)))
	})

  tags = merge(var.tags, {
    Role = "zabbix"
  })
}
