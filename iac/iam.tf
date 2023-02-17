##############################################################
# EC2 aim role and policy
##############################################################

#Specify who can use the role
data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
  tags = var.tags
}

# Specify what can be done by the one uses the role
resource "aws_iam_policy" "airflow_ec2" {
  name = "airflow_ec2_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretmanager:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
  tags = var.tags
}

# Create the role with Inline_policy and iam policy
resource "aws_iam_role" "airflow_ec2" {
  name                = "airflow_ec2_role"
  assume_role_policy  = data.aws_iam_policy_document.instance_assume_role_policy.json
  managed_policy_arns = [aws_iam_policy.airflow_ec2.arn]
  tags                = var.tags
}


resource "aws_iam_instance_profile" "airflow_ec2" {
  name = "airflow_ec2"
  role = aws_iam_role.airflow_ec2.name
  tags = var.tags
}
