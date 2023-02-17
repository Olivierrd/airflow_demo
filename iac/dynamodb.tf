##############################################################
# Create Json DB to host factory DAG configurations
##############################################################

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "airflow_factory_dag_conf"
  read_capacity  = 2
  write_capacity = 1
  tags           = var.tags
}