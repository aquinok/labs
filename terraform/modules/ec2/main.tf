data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-"
  public_key = var.public_key

  tags = merge(var.tags, {
    Name = "${var.name}-key"
  })
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  key_name                    = aws_key_pair.this.key_name
  
  user_data                   = var.user_data
  user_data_replace_on_change = true
  iam_instance_profile        = var.iam_instance_profile

  tags = merge(var.tags, {
    Name = "${var.name}-ubuntu-2404"
  })
}
