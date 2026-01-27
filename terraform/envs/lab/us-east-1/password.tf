resource "random_password" "ubuntu" {
  length  = 24
  special = true
}

# Store plaintext so you can recall it while the env is up
resource "aws_secretsmanager_secret" "ubuntu_password" {
  name                    = "${var.name}/ubuntu-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ubuntu_password" {
  secret_id     = aws_secretsmanager_secret.ubuntu_password.id
  secret_string = random_password.ubuntu.result
}

output "ubuntu_password_secret_arn" {
  value     = aws_secretsmanager_secret.ubuntu_password.arn
  sensitive = true
}

# Optional but handy for CLI lookups
output "ubuntu_password_secret_name" {
  value     = aws_secretsmanager_secret.ubuntu_password.name
  sensitive = true
}
