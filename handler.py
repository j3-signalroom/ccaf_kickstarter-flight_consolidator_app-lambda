from pyflink.table import TableEnvironment, Schema, DataTypes, FormatDescriptor
from pyflink.table.catalog import ObjectPath
from pyflink.table.confluent import ConfluentTableDescriptor, ConfluentSettings, ConfluentTools
from pyflink.table.expressions import col, lit
import uuid
from functools import reduce
import boto3
from botocore.exceptions import ClientError
import json
import logging


__copyright__  = "Copyright (c) 2024 Jeffrey Jonathan Jennings"
__credits__    = ["Jeffrey Jonathan Jennings"]
__license__    = "MIT"
__maintainer__ = "Jeffrey Jonathan Jennings"
__email__      = "j3@thej3.com"
__status__     = "dev"


# Confluent Cloud for Apache Flink Secrets Keys
ENVIRONMENT_ID = "environment.id"
FLINK_API_KEY = "flink.api.key"
FLINK_API_SECRET = "flink.api.secret"
FLINK_CLOUD = "flink.cloud"
FLINK_COMPUTE_POOL_ID = "flink.compute.pool.id"
FLINK_PRINCIPAL_ID = "flink.principal.id"
FLINK_REGION = "flink.region"
ORGANIZATION_ID = "organization.id"


def lambda_handler(event, context):
    """
    This AWS Lambda function is the main entry point for the Flink app.  It defines
    the Kafka sink table, reads from source tables, transforms the data, and writes
    to the sink.

    Args:
        event (dict): The event data passed to the Lambda function.
        context (object): The metadata about the invocation, function, and execution environment.

    Returns:
        statusCode: 200 for a successfully run of the function.
        body: List of the secret names updated by the function.
    """
    # Set up the logger.
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # Check all required fields for the event exist.
    required_event_fields = ["catalog_name", "database_name", "ccaf_secrets_path"]
    for field in required_event_fields:
        if field not in event:
            logger.error(f"Missing required field: {field}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Missing required field: {field}'})
            }
        
    # Get the catalog name, database name, and secrets path from the event.
    catalog_name = event.get("catalog_name", "").lower()
    database_name = event.get("database_name", "").lower()
    secrets_path = event.get("ccaf_secrets_path", "")

    try:
        get_secret_value_response = boto3.client('secretsmanager').get_secret_value(SecretId=secrets_path)
        settings = json.loads(get_secret_value_response['SecretString'])

        # Create the TableEnvironment with the Confluent Cloud for Apache Flink settings.
        tbl_env = TableEnvironment.create(
            ConfluentSettings
                .new_builder()
                .set_cloud(settings[FLINK_CLOUD])
                .set_region(settings[FLINK_REGION])
                .set_flink_api_key(settings[FLINK_API_KEY])
                .set_flink_api_secret(settings[FLINK_API_SECRET])
                .set_organization_id(settings[ORGANIZATION_ID])
                .set_environment_id(settings[ENVIRONMENT_ID])
                .set_compute_pool_id(settings[FLINK_COMPUTE_POOL_ID])
                .build()
        )
    except ClientError as e:
        logger.error("Failed to get secrets from the AWS Secrets Manager because of %s.", e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    # The catalog name and database name are used to set the current catalog and database.
    tbl_env.use_catalog(catalog_name)
    tbl_env.use_database(database_name)
    catalog = tbl_env.get_catalog(catalog_name)

    # The Kafka sink table Confluent Cloud environment Table Descriptor with Avro serialization.
    flight_avro_table_descriptor = (
        ConfluentTableDescriptor
            .for_managed()
            .schema(
                Schema
                    .new_builder()
                    .column("departure_airport_code", DataTypes.STRING())
                    .column("flight_number", DataTypes.STRING())
                    .column("email_address", DataTypes.STRING())
                    .column("departure_time", DataTypes.STRING())
                    .column("arrival_time", DataTypes.STRING())
                    .column("arrival_airport_code", DataTypes.STRING())
                    .column("confirmation_code", DataTypes.STRING())
                    .column("airline", DataTypes.STRING())
                    .build())
            .distributed_by_into_buckets(1, "departure_airport_code", "flight_number")
            .key_format(FormatDescriptor.for_format("avro-registry").build())
            .value_format(FormatDescriptor.for_format("avro-registry").build())
            .build()
    )
    try:
        # Checks if the table exists.  If it does not, it will be created.
        flight_avro_table_path = ObjectPath(tbl_env.get_current_database(), "flight_avro")
        if not catalog.table_exists(flight_avro_table_path):
            tbl_env.create_table(
                flight_avro_table_path.get_full_name(),
                flight_avro_table_descriptor
            )
            logger.info(f"Sink table '{flight_avro_table_path.get_full_name()}' created successfully.")
        else:
            logger.info(f"Sink table '{flight_avro_table_path.get_full_name()}' already exists.")
    except Exception as e:
        logger.error(f"A critical error occurred during the processing of the table because {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    # The first table is the SkyOne table that is read in.
    airline = tbl_env.from_path(f"{catalog_name}.{database_name}.skyone_avro")

    # Get the schema and columns from the airline table.
    schema = airline.get_schema()

    # The columns that are not needed in the table the represents general airline flight data.
    exclude_airline_columns = ["key", "flight_duration", "ticket_price", "aircraft", "booking_agency_email", "$rowtime"]
    
    # Get only the columns that are not in the excluded columns list.
    flight_expressions = [col(field) for field in schema.get_field_names() if field not in exclude_airline_columns]
    flight_columns = [field for field in schema.get_field_names() if field not in exclude_airline_columns]

    # The first table is the SkyOne table that is read in.
    skyone_airline = airline.select(*flight_expressions, lit("SkyOne"))

    # The second table is the Sunset table that is read in.
    sunset_airline = airline.select(*flight_expressions, lit("Sunset"))

    # Build a compound expression, ensuring each column is not null
    filter_condition = reduce(
        lambda accumulated_columns, current_column: accumulated_columns & col(current_column).is_not_null, flight_columns[1:], col(flight_columns[0]).is_not_null
    )

    # Combine the two tables.
    combined_airlines = (
        skyone_airline.union_all(sunset_airline)
        .alias(*flight_columns, "airline")
        .filter(filter_condition)
    )

    # Insert the combined record into the sink table.
    try:
        statement_name = "combined-flight-data-" + str(uuid.uuid4())
        tbl_env.get_config().set("client.statement-name", statement_name)
        table_result = combined_airlines.execute_insert(flight_avro_table_path.get_full_name())
        processed_statement_name = ConfluentTools.get_statement_name(table_result)
        print("Statement has been deployed as: " + processed_statement_name)
    except Exception as e:
        logger.error(f"An error occurred during data insertion: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
