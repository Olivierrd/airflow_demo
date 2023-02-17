##############################################################
# RDS Creation for Airflow data
##############################################################
locals {
  airflow_password = jsondecode(aws_secretsmanager_secret_version.airflow_db_user_admin_version.secret_string)["airflow_db_admin_password"]
  airflow_username = local.airflow_db_admin_creds.airflow_db_user_admin
}

/*### SECURITY GROUP for RDS
resource "aws_security_group" "rds_security_group" {
  name   = "rds-sg-${module.labels.name_suffix}"
  vpc_id = data.aws_subnet_ids.vpc_datalake_privsnet.vpc_id
}*/

/*
### RDS SUBNET GROUP
resource "aws_db_subnet_group" "airflow_rds_sb_group" {
  name       = "orchestration-rds-sub-group"
  subnet_ids = data.aws_subnet_ids.vpc_datalake_privsnet.ids
  tags       = var.tags
}*/

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "airflow"
  engine               = "postgres"
  engine_version       = "5.7"
  instance_class       = "db.t3.medium"
  username             = local.airflow_username
  password             = local.airflow_password
  skip_final_snapshot  = true
  tags                 = var.tags
}

