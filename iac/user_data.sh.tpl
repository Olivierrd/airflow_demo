#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

PATH=/home/ec2-user/venv/bin:"$PATH"
AIRFLOW_HOME=/home/ec2-user/airflow
######### Database creation
DB_ADRESS=${db_adress}
APP_DB_NAME=${app_db_name}

# Airflow credentials
ADMIN_DB_USER=$(aws --region ${aws_region} secretsmanager get-secret-value --secret-id "rds/airflow_db_user_admin" --query "SecretString" --output text | jq -r ".airflow_db_user_admin")
ADMIN_DB_PASSWORD=$(aws --region ${aws_region} secretsmanager get-secret-value --secret-id "rds/airflow_db_user_admin" --query "SecretString" --output text | jq -r ".airflow_db_admin_password")


########## Update the airflow_env.sh with connexion info
touch /home/ec2-user/airflow/airflow_env
chown -R ec2-user:ec2-user /home/ec2-user/airflow/airflow_env
sudo echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN=\"postgres://$${ADMIN_DB_USER}:$${ADMIN_DB_PASSWORD}@$${DB_ADRESS}:5432/$${APP_DB_NAME}\"" >> /home/ec2-user/airflow/airflow_source
sudo echo "export ENABLE_PROXY_FIX=\"True\"" >> /home/ec2-user/airflow/airflow_source
sudo echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN=\"postgres://$${ADMIN_DB_USER}:$${ADMIN_DB_PASSWORD}@$${DB_ADRESS}:5432/$${APP_DB_NAME}\"" >> /home/ec2-user/airflow/airflow_env
sudo echo "ENABLE_PROXY_FIX=\"True\"" >> /home/ec2-user/airflow/airflow_env

source activate  airflow

##########
mkdir -p $AIRFLOW_HOME
sudo chmod -R 777 $AIRFLOW_HOME

if [ ! -f "$AIRFLOW_HOME/airflow.cfg" ]; then
    export AIRFLOW_HOME=$AIRFLOW_HOME
    PATH=/home/ec2-user/venv/bin:"$PATH"
    source activate airflow
    airflow db init
    source /home/ec2-user/airflow/airflow_source
    airflow db upgrade
fi

##### Get ssh key to connect to Bitbucket
aws --region ${aws_region} secretsmanager get-secret-value --secret-id "airflow/ssh/public" --query "SecretString" --output text > /home/ec2-user/.ssh/id_rsa.pub
aws --region ${aws_region} secretsmanager get-secret-value --secret-id "airflow/ssh/private" --query "SecretString" --output text > /home/ec2-user/.ssh/id_rsa


if [  -d  "$AIRFLOW_HOME/dags" ]; then
   sudo rm -rf "$AIRFLOW_HOME/dags"
fi

sudo mkdir -p "$AIRFLOW_HOME/dags"

sudo ssh-keyscan bitbucket.org >> /home/ec2-user/.ssh/known_hosts
chown -R ec2-user:ec2-user "$AIRFLOW_HOME/dags"
runuser -l  ec2-user -c 'APP_REPO=$(aws ssm get-parameter --name '/airflow/repo' --query 'Parameter.Value' --output text  --region ${aws_region}) && git clone git@$APP_REPO  ~/airflow/dags'

chown -R ec2-user:ec2-user "$AIRFLOW_HOME/dags"

# For test (uncomment 2 lines above to get the final version)
touch $AIRFLOW_HOME/dags_test_from_userdata
chown -R ec2-user:ec2-user "$AIRFLOW_HOME"

mkdir -p /var/log/git-sync
chmod -R 777 /var/log/git-sync

echo "PATH=/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin" >>  /etc/cron.d/git-dags

echo "*/1 * * * * ec2-user (cd $${AIRFLOW_HOME}/dags && git fetch && git reset --hard origin/${git_branch}) >>/var/log/git-sync/daily.log 2>&1" >> /etc/cron.d/git-dags

## EBS additionnal Volume mounting
mkdir /airflow
mkfs -t xfs ${ebs_device_name}
mount ${ebs_device_name} /airflow
mkdir /airflow/log
chown -R ec2-user:ec2-user /airflow

## Auto-mount EBS in case reboot
STRING_TO_ADD="${ebs_device_name} /airflow xfs defaults,nofail 0 2"
sudo echo $STRING_TO_ADD >> /etc/fstab


####Create Unit files for Airflow systemd daemons
sudo wget -O /usr/lib/systemd/system/airflow-webserver.service https://raw.githubusercontent.com/apache/airflow/master/scripts/systemd/airflow-webserver.service
sudo wget -O /usr/lib/systemd/system/airflow-scheduler.service https://raw.githubusercontent.com/apache/airflow/master/scripts/systemd/airflow-scheduler.service
sudo wget -O /usr/lib/systemd/system/airflow-worker.service https://raw.githubusercontent.com/apache/airflow/master/scripts/systemd/airflow-worker.service

sudo sed -i 's|EnvironmentFile=.*|EnvironmentFile=/home/ec2-user/airflow/airflow_env|g' /usr/lib/systemd/system/airflow-*.service
sudo sed -i 's|User=.*|User=ec2-user|g' /usr/lib/systemd/system/airflow-*.service
sudo sed -i 's|Group=.*|Group=ec2-user|g' /usr/lib/systemd/system/airflow-*.service

sudo sed -i 's|.*ExecStart=.*|ExecStart=/bin/sh -c '\''cd /home/ec2-user/ \&\& source venv/bin/activate airflow \&\& airflow webserver -p 8080'\''|g' /usr/lib/systemd/system/airflow-webserver.service
sudo sed -i 's|.*ExecStart=.*|ExecStart=/bin/sh -c '\''cd /home/ec2-user/ \&\& source venv/bin/activate airflow \&\& airflow scheduler'\''|g' /usr/lib/systemd/system/airflow-scheduler.service
sudo sed -i 's|.*ExecStart=.*|ExecStart=/bin/sh -c '\''cd /home/ec2-user/ \&\& source venv/bin/activate airflow \&\& airflow celery worker'\''|g' /usr/lib/systemd/system/airflow-worker.service

#increase dagbag_import_timeout:
sudo sed -i 's|^dagbag_import_timeout\s.*|dagbag_import_timeout = 30.0|g' $AIRFLOW_HOME/airflow.cfg

sudo chown -R ec2-user:ec2-user /airflow/

sudo systemctl daemon-reload

####Update packages
sudo yum update -y

####Start Webserverq
sudo systemctl start airflow-webserver.service
sudo systemctl enable airflow-webserver.service

####Start Scheduler
sudo systemctl start airflow-scheduler.service
sudo systemctl enable airflow-scheduler.service

## Install SSM DOCUMENT that returns Timeout error https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-al.html
sudo yum install -y https://s3.eu-west-3.amazonaws.com/amazon-ssm-eu-west-3/latest/linux_amd64/amazon-ssm-agent.rpm
