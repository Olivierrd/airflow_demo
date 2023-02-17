##############################################################
# EC2 instance that hosts Airflow
##############################################################

resource "aws_instance" "airflow" {
  ami                   = "ami-00575c0cbc20caf50"
  instance_type         = "m5.large"
  iam_instance_profile  = aws_iam_instance_profile.airflow_ec2.name
  user_data             = templatefile("user_data.sh.tpl")
  tags                  = var.tags

}

##############################################################
# EBS volume link to the instance
##############################################################

# In order to prevent from logs to overflow the airflow ec2, you should have two EBS
# - One with logs
# - The other with airflow installation

resource "aws_ebs_volume" "airflow_logs" {
  availability_zone = "eu-west-3"
  size              = 30
  iops              = "gp3"
  tags              = var.tags
}

resource "aws_ebs_volume" "airflow_install" {
  availability_zone = "eu-west-3"
  size              = 30
  iops              = "gp3"
  tags              = var.tags
}

##############################################################
# EBS volume attachement to EC2
##############################################################

resource "aws_volume_attachment" "airflow_install" {
  device_name = "/dev/sdi"
  volume_id   = aws_ebs_volume.airflow_install.id
  instance_id = aws_instance.airflow.id
}

resource "aws_volume_attachment" "airflow_logs" {
  device_name = "/dev/sdl"
  volume_id   = aws_ebs_volume.airflow_logs.id
  instance_id = aws_instance.airflow.id
}