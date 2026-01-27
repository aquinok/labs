variable "aws_region" {
  description = "Region for backend resources (S3/DynamoDB)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project tag/name prefix"
  type        = string
  default     = "labs"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project = "labs"
  }
}

