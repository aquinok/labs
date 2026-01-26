variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "lab"
}

variable "az" {
  type        = string
  description = "Pick a valid AZ in the region"
  default     = "us-east-1a"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to SSH in"
  default     = ["24.243.5.64/32"]
}

variable "public_key_path" {
  type        = string
  description = "Path to your SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "labs"
    Env     = "lab"
  }
}
