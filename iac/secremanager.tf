##############################################################
# Create secrets for Airflow DB
##############################################################


# Generate random password for airflow DB admin
resource "random_password" "airflow_db_admin_password" {
  length    = 10
  min_upper = 2
  min_lower = 2
  special   = false
}

locals {
  airflow_db_admin_creds = {
    airflow_db_user_admin     = var.airflow_db_user_admin,
    airflow_db_admin_password = random_password.airflow_db_admin_password.result
  }
}

#create secret
resource "aws_secretsmanager_secret" "airflow_db_user_admin" {
  name                    = "rds/airflow_db_user_admin"
  description             = "Credentials for airflow to get access to RDS"
  recovery_window_in_days = 0
  tags                    = var.tags

}

#store secret
resource "aws_secretsmanager_secret_version" "airflow_db_user_admin_version" {
  secret_id     = aws_secretsmanager_secret.airflow_db_user_admin.id
  secret_string = jsonencode(local.airflow_db_admin_creds)
}