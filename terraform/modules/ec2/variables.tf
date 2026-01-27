variable "name" {
  type        = string
  description = "Name prefix"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  type        = string
}

variable "vpc_security_group_ids" {
  type        = list(string)
}

variable "public_key" {
  type        = string
  description = "SSH public key material (contents of ~/.ssh/id_rsa.pub)"
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "user_data" {
  type        = string
  description = "Cloud-init user_data"
  default     = null
}

variable "iam_instance_profile" {
  type        = string
  description = "Optional instance profile name to attach to the instance"
  default     = null
}

variable "node_count" {
  type    = number
  default = 1
}
