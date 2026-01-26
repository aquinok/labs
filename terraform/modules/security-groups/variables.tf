variable "name" {
  type        = string
  description = "Name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to attach SG to"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to SSH in"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type        = map(string)
  default     = {}
}

