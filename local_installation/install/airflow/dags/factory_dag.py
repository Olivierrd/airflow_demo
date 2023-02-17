from airflow import DAG
from datetime import timedelta
from airflow.operators.python_operator import PythonOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.operators.dummy_operator import DummyOperator
from datetime import datetime
import json
import pendulum

from Dynamic_dag.utils import get_dags_name, get_dags_confs
from Dynamic_dag.dag_steps import wait, copy, create_table, notify

LOCAL_TZ = pendulum.timezone("Europe/Paris")
ENV= 'test'

def create_dag(dag, **kwargs):
    with dag:
        first_step = PythonOperator(
            task_id='1st_step',
            python_callable=wait,
            op_args=[],
            provide_context=True,
            dag=dag
        )

        second_step = PythonOperator(
            task_id='2nd_step',
            python_callable=wait,
            op_args=[],
            provide_context=True,
            dag=dag
        )

        third_copy_data = PythonOperator(
            task_id='3rd_copy_data',
            python_callable=copy,
            op_args=[tables2copy],
            provide_context=True,
            dag=dag
        )

        end = DummyOperator(
            task_id='end',
            dag=dag
        )

        create_wh_table = PythonOperator(
            task_id='create_wh_table',
            python_callable=create_table,
            provide_context=True,
            op_args=[tables],
            dag=dag
        )

        notif_failure = PythonOperator(
            task_id='ms_teams_notif_failure',
            python_callable=notify,
            op_args=[f"[{ENV}] Failed message!", "Please refer to your take"],
            trigger_rule=TriggerRule.ONE_FAILED,
            dag=dag
        )

        notif_success = PythonOperator(
            task_id='ms_teams_notif_success',
            python_callable=notify,
            op_args=[f"[{ENV}] Success message!", ""],
            dag=dag
        )

        first_step >> second_step >> third_copy_data >> end >> create_wh_table >> [notif_failure, notif_success]

        def convert_to_csv(tablename):
            from Dynamic_dag.dag_steps import convert

            return PythonOperator(
                task_id=f'convert_2csv_{tablename[:20]}',
                python_callable=convert,
                op_args=[tablename],
                retries=0,
                dag=T2S_DAG
            )

        # Case of tables to convert to CSV
        for prefix in tables2conv:
            tablename = prefix.split('/')[5]
            convert = convert_to_csv(tablename)
            second_step >> convert >> end

    return dag

source = "remote"
for dag_name in get_dags_name(source):
    tables, tables2conv, tables2copy, confs, teams_channels, DA_EMAIL = get_dags_confs(source, dag_name)

    default_args = {
        'start_date': datetime(2021, 1, 15, 12, 0, tzinfo=LOCAL_TZ),
        'owner': 'ec2-user',
        'depends_on_past': False,
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': int(confs["nb_retries"]),
        'retry_delay': timedelta(minutes=confs["retry_delay"]),
        'email': DA_EMAIL,
        'max_active_runs': 1
    }

    T2S_DAG = DAG(
        dag_name,
        default_args=default_args,
        description="DAG test permet de copier des données en les convertissant ou non",
        catchup=False,
        schedule_interval=confs["schedule_cron"],
        params={"define_variable": "10"}
    )

    globals()[dag_name] = create_dag(T2S_DAG)
