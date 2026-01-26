variable "name" {
  type        = string
  description = "US-East-1 VPC"
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR"
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR"
  default     = "10.10.1.0/24"
}

variable "az" {
  type        = string
  description = "Availability Zone for the public subnet"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags"
  default     = {}
}
