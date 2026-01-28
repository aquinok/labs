resource "random_password" "ubuntu" {
  length  = 24
  special = true
}

resource "random_password" "zabbix_admin" {
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

# Store Zabbix UI/API admin credentials as JSON
resource "aws_secretsmanager_secret" "zabbix_admin" {
  name                    = "${var.name}/zabbix-admin"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "zabbix_admin" {
  secret_id = aws_secretsmanager_secret.zabbix_admin.id
  secret_string = jsonencode({
    username = "Admin"
    password = random_password.zabbix_admin.result
  })
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

output "zabbix_admin_secret_name" {
  value     = aws_secretsmanager_secret.zabbix_admin.name
  sensitive = true
}
