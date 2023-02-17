export AIRFLOW_HOME=/Users/olivierrandavel/Git_projects/airflow_demo/local_installation/install/airflow

#create folders
mkdir -p ${AIRFLOW_HOME}/logs
mkdir -p ${AIRFLOW_HOME}/airflow_env

# Create virtualenv
virtualenv -p python3 ${AIRFLOW_HOME}/airflow_env
source ${AIRFLOW_HOME}/airflow_env/bin/activate

cd ${AIRFLOW_HOME}
pip3 install -r requirements.txt

# First init
airflow db init
sed -i 's|load_examples = True|load_examples = False|g' $AIRFLOW_HOME/airflow.cfg

# Second init
airflow db init


# Create admin user
airflow users create \
--username admin \
--password admin \
--firstname Olivier \
--lastname Randavel \
--role Admin \
--email admin@example.com


# Start scheduler
airflow scheduler \
--pid ${AIRFLOW_HOME}/logs/airflow-scheduler.pid \
--stdout ${AIRFLOW_HOME}/logs/airflow-scheduler.out \
--stderr ${AIRFLOW_HOME}/logs/airflow-scheduler.out \
-l ${AIRFLOW_HOME}/logs/airflow-scheduler.log \
-D

# Start webserver
airflow webserver \
--pid ${AIRFLOW_HOME}/logs/airflow-webserver.pid \
--stdout ${AIRFLOW_HOME}/logs/airflow-webserver.out \
--stderr ${AIRFLOW_HOME}/logs/airflow-webserver.out \
-l ${AIRFLOW_HOME}/logs/airflow-webserver.log \
-D

# stop webserver
#kill $(lsof -i tcp:8080 | grep "Python" | awk '{print $2}' | head -n 1)

# stop scheduler
#kill $(ps -ef | grep "airflow scheduler" | awk '{print $2}' | head -n 1)
