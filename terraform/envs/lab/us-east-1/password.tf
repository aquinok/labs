resource "random_password" "ubuntu" {
  length  = 24
  special = true
}

# Store plaintext safely so YOU can recall it when the env is up
resource "aws_secretsmanager_secret" "ubuntu_password" {
  name                    = "${var.name}/ubuntu-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ubuntu_password" {
  secret_id     = aws_secretsmanager_secret.ubuntu_password.id
  secret_string = random_password.ubuntu.result
}

# Hash it for cloud-init (no plaintext in user_data)
data "external" "ubuntu_pw_hash" {
  program = [
    "python3",
    "-c",
    <<EOF
import crypt, json, sys
q=json.load(sys.stdin)
pw=q["pw"]
salt = crypt.mksalt(crypt.METHOD_SHA512)
print(json.dumps({"hash": crypt.crypt(pw, salt)}))
EOF
  ]

  query = {
    pw = random_password.ubuntu.result
  }
}

locals {
  ubuntu_password_hash = data.external.ubuntu_pw_hash.result.hash
}

output "ubuntu_password_secret_arn" {
  value     = aws_secretsmanager_secret.ubuntu_password.arn
  sensitive = true
}
