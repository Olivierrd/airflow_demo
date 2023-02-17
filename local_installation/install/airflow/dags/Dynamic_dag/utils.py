import boto3

client_dynamodb = boto3.client("dynamodb")

def get_dags_name_from_db(dynamo_table="airflow_factory_dag_conf"):
    """
    Return a list with DynamoDB keys id for items where DE_CHECK=True
    :param dynamo_table: name of dynamodb table: 'orchestration_conf-'+ENV+'datammh' or  'orchestration_dataprep_conf-'+ENV+'datammh'
    :param kwargs: DAG context
    :return: return a list of DAGs id
    """
    DAGS = []
    response = client_dynamodb.scan(
        TableName=dynamo_table,
        ProjectionExpression="dag_name, DE_CHECK"
    )
    for item in response['Items']:
        try:
            if item['DE_CHECK']['BOOL']:
                DAGS.append(item['dag_name']['S'])
        except Exception as e:
            print(f"Problem loading item {item}")
    return DAGS

def get_dags_confs_from_db(search_key, dynamo_table= "airflow_factory_dag_conf"):
    """
    Load item informations from configurations DynamoDB table
    :param dynamo_table: name of dynamodb table: 'orchestration_conf-'+ENV+'datammh' or  'orchestration_dataprep_conf-'+ENV+'datammh'
    :param search_key: name of partition key (UC or Dataprep name)
    :return: informations of the item (Tables, Configurationss and MS Teams Channels configs)
    """
    search_key = search_key.split('/')[0] #remove '/'
    try:
        response = client_dynamodb.get_item(
            TableName=dynamo_table,
            Key={
                  "dag_name": {
                    "S": search_key
                  }
            },
        )
        tables_conf = response['Item']['tables']['L']
        tables = [table['M']['name']['S'] for table in tables_conf]
        tables2conv = [table['M']['name']['S'] for table in tables_conf
            if table['M'].get('conv2csv', {}).get('BOOL', False)]
        tables2copy = [table['M']['name']['S'] for table in tables_conf
            if table['M'].get('conv2csv', {}).get('BOOL', True)]
        confs = response['Item']['configurations']['M']
        confs = {
            "default_NB_versions": int(confs.get('default_NB_versions', {}).get('N', 3)),
            "nb_retries": int(confs['NB_Retry']['N']),
            "retry_delay": int(confs['Retry_delay']['N']),
            "schedule_cron": confs['Scheduling']['S']
        }
        teams_channels = response['Item']['ch_teams']['M']
        DA = response['Item']['DA']['L'][0]['S']
    except Exception as e:
        print(f"Couldn't retrieve info for {search_key} : {e}")
        return "", "", "", "", ""
    return tables, tables2conv, tables2copy, confs, teams_channels, DA


def get_dags_name(source):
    import json
    if source == "local":
        f = open('/Users/olivierrandavel/Git_projects/airflow_demo/local_installation/install/airflow/dags/Dynamic_dag/setting.json', "r")
        data = json.loads(f.read())
        return [*data]
    elif source == "remote":
        data = get_dags_name_from_db()
    return data

def get_dags_confs_locally(dagname):
    import json
    f = open('/Users/olivierrandavel/Git_projects/airflow_demo/local_installation/install/airflow/dags/Dynamic_dag/setting.json', "r")
    data = json.loads(f.read())[dagname]
    confs = {
        "default_NB_versions": [*data['configurations']['M']['default_NB_versions']['N']][0],
        "nb_retries": [*data['configurations']['M']['NB_Retry']['N']][0],
        "retry_delay": int([*data['configurations']['M']['Retry_delay']['N']][0]),
        "schedule_cron": data['configurations']['M']['Scheduling']['S']
    }
    DA_EMAIL = data['DA']['L'][0]['S']
    teams_channels = data['ch_teams']["M"]['ch_host']['S']
    tables2copy = [i['M']['name']['S'] for i in [*data['tables']['L']] if not i['M']["conv2csv"]['BOOL'] ]
    tables2conv = [i['M']['name']['S'] for i in [*data['tables']['L']] if i['M']["conv2csv"]['BOOL'] ]
    tables = tables2conv + tables2copy

    return tables, tables2conv, tables2copy, confs, teams_channels, DA_EMAIL


def get_dags_confs(source, dagname):
    if source == "remote":
        return get_dags_confs_from_db(dagname)
    elif source == "local":
        return get_dags_confs_locally(dagname)