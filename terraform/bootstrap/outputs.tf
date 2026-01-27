output "backend_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "backend_dynamodb_table" {
  value = aws_dynamodb_table.tflock.name
}

output "backend_region" {
  value = var.aws_region
}
