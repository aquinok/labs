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
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [module.sg.ssh_sg_id]
  public_key             = file(pathexpand(var.public_key_path))

  user_data = templatefile("${path.module}/user_data.yaml.tftpl", {
    ubuntu_password_hash = local.ubuntu_password_hash
    ssh_public_key       = chomp(file(pathexpand(var.public_key_path)))
  })

  tags = var.tags
}
