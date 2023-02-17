##############################################################
# EC2 needs to communicate with RDS
##############################################################

resource "aws_vpc" "airflow-vpc" {
    tags = var.tags
}

resource "aws_security_group" "airflow_ec2" {
    name = "ec2"
    vpc_id =  aws_vpc.airflow-vpc.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = var.tags
}

resource "aws_security_group" "airflow_rds" {
    name = "rds"
    vpc_id =  aws_vpc.airflow-vpc.id
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [aws_security_group.airflow_ec2.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }
    tags = var.tags
}

##############################################################
# User needs to communicate with EC2
##############################################################

#From the UI we will add an ingress rule on EC2 to authorized my IP address