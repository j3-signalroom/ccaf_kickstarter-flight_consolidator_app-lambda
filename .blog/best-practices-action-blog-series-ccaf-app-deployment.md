# Confluent Cloud for Apache Flink: Best Practices for Deploying Table API Applications with GitHub and Terraform

> _This is the first in our year-long “Best Practices in Action” series, where my team and I will share proven strategies for success._

**TL; DR:** _Kickstart your Flink app on Confluent Cloud by packaging it as an AWS Lambda, then power it all with a GitHub + Terraform CI/CD pipeline._

From the moment [Confluent Cloud for Apache Flink (CCAF)](https://docs.confluent.io/cloud/current/flink/overview.html) entered early preview in late 2023, I was immediately captivated by its possibilities. Determined to leverage its power, I integrated the [Confluent Terraform Provider](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs) with GitHub to create a robust CI/CD pipeline—enabling my organization and our clients to benefit from reliable, managed Flink solutions. By following Confluent’s [recommendations](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/deploy-flink-sql-statement.html) and [reference examples](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations), I swiftly developed a Terraform-based workflow that automated the delivery of Flink SQL statements. However, when Confluent released [Table API](https://docs.confluent.io/cloud/current/flink/reference/table-api.html) support for Java and Python in mid-2024, it became clear that an entirely new approach was needed. With no predefined best practices for deploying Table API-based Flink applications in a CI/CD pipeline, I found myself charting untested territory to ensure we could fully harness this expanded functionality.

![spongebob-question](images/spongebob-question.gif)

After weighing the trade-offs of different strategies, I landed on the following best-practice approach for automating a CI/CD pipeline for CCAF:
1.	**Package Your Code:** Build an AWS Lambda function (AWS is my hyperscaler of choice).
2.	**Dockerize:** Create a Dockerfile for the Lambda function.
3.	**Set Up ECR:** Create an AWS Elastic Container Registry (ECR) to host Docker images.
4.	**Build & Publish:** From GitHub, build the Docker image and push it to ECR.
5.	**Provision Lambda:** Use Terraform from GitHub to spin up the Lambda function.
6.	**Deploy Flink App:** Invoke the Lambda (via Terraform) to deploy your Confluent Cloud for Apache Flink application.

The diagram below brings this entire pipeline to life, showing how each component fits seamlessly together to deliver your Confluent Cloud for Apache Flink application:

![deployment-flow](images/deployment-flow.png)

## 1.0 Why This Approach

**Why did I choose the AWS Lambda service over hosting code in a docker container in the AWS Fargate container service?**  While both services are powerful serverless compute options, each shines in different scenarios:

- AWS Lambda is ideal for _event-driven_, _short-lived_, and _stateless_ tasks.
- AWS Fargate excels in running _containerized_, _long-running_, and _stateful_ applications.

Because deploying a Flink Application (a.k.a. Flink Job) to Confluent Cloud for Apache Flink (CCAF) is a _short-lived_, _**one-time push**_ that requires _no persistent state_, AWS Lambda is a wise choice, IMHO.

![indiana-jones-last-crusade](images/indiana-jones-last-crusade.gif)

**Why Dockerize the Lambda function?**  It’s a strategic choice when your code requires large, intricate dependencies—like the `confluent-flink-table-api-python-plugin`, which needs both Java and Python in one environment.  By packaging everything into a Docker container, you gain full control over your runtime, seamlessly manage custom dependencies, and streamline CI/CD pipelines for consistent, frictionless deployments.

**Why AWS ECR?**  As the native container registry in AWS, ECR delivers frictionless integration with AWS Lambda, ensuring secure, efficient storage and management of Docker images—all within the AWS ecosystem.

**Why Terraform?**  It unlocks the power of automated infrastructure provisioning, bringing Infrastructure as Code (IaC) principles to your AWS Lambda environment. This modern DevOps approach empowers you to build, deploy, and maintain resilient, scalable applications—all from a single source of truth.

## 2.0 Now See This Best Practice in Action
To illustrate this approach, I’m leveraging the [Apache Flink Kickstarter Flink App—powered by Python on Confluent Cloud for Apache Flink (CCAF)](https://github.com/j3-signalroom/apache_flink-kickstarter/tree/main/ccaf)—-as a prime example of the code you’d deploy to CCAF. Now, let’s dive right in!

![shummer-death_dive](images/shummer-death_dive.gif)

### 2.1 The Code

If you want to get right into the code, you can find the full implementation in the [GitHub repository](https://github.com/j3-signalroom/ccaf_kickstarter-flight_consolidator_app-lambda).  Here is a detail overview of the code that follows:

#### 2.1.1 Python Intepreter, Packages and Dependencies + Java 17 JDK you need

To get started, you’ll need to set up your Python virtual environment to run Python 3.11.x intepreter with the following packages and dependencies:
- ```confluent-flink-table-api-python-plugin```, verion `1.20.42` or later -- this is the Python Table API plugin for Confluent Cloud for Apache Flink, which allows you to run Python code on Flink.
- ```boto3```, version `1.35.90` or later -- this is the AWS SDK for Python, which allows you to interact with AWS services.  The AWS Service the app interacts with is AWS Lambda and AWS Secrets Manager.
- ```setuptools```, version `65.5.1` or later -- allows you to install a package without copying any files to your interpreter directory (e.g. the `site-packages` directory).  This allows you to modify your source code and have the changes take effect without you having to rebuild and reinstall.

> You maybe wondering why Python 3.11.x.  Well, `confluent-flink-table-api-python-plugin` runs on top of [`PyFlink 1.20.x`](https://nightlies.apache.org/flink/flink-docs-release-1.20/api/python/), and its upper limit [support for Python is 3.11.x](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/python/installation/).

Here’s the `pyproject.toml` file that specifies the Python version and dependencies:
```python
[project]
name = "flight_consolidator_app"
version = "0.03.00.000"
description = "Confluent Cloud for Apache Flink (CCAF) Flight Consolidator App Lambda"
readme = "README.md"
authors = [
    { name = "Jeffrey Jonathan Jennings (J3)", email = "j3@thej3.com" }
]
requires-python = "~=3.11.9"
dependencies = [
    "boto3>=1.35.90",
    "confluent-flink-table-api-python-plugin>=1.20.42",
    "setuptools>=65.5.1",
]
```

Here's the `.python-version` file that specifies the Python version being used:
```text
3.11.9
```

Plus, you’ll need the Java 17 JDK to run the `confluent-flink-table-api-python-plugin`, because it calls Java JAR files.

##### 2.1.1.1 A Word on the Python Package Manager of Choice: Astral `uv`
Now, if you are new to my post on [LinkedIn](https://www.linkedin.com/in/jeffreyjonathanjennings/), [blogs](https://thej3.com/), or [GitHub projects](https://github.com/j3-signalroom), you don't know, but I am a total Fanboy of [Astral](https://astral.sh/)'s `uv` Python Package Manager.  You maybe asking yourself why.  Well, `uv` is an incredibly fast Python package installer and dependency resolver, written in [**Rust**](https://github.blog/developer-skills/programming-languages-and-frameworks/why-rust-is-the-most-admired-language-among-developers/), and designed to seamlessly replace `pip`, `pipx`, `poetry`, `pyenv`, `twine`, `virtualenv`, and more in your workflows. By prefixing `uv run` to a command, you're ensuring that the command runs in an optimal Python environment **AUTOMATICALLY**.

Curious to learn more about [Astral](https://astral.sh/)'s `uv`? Check these out:
- Documentation: Learn about [`uv`](https://docs.astral.sh/uv/).
- Video: [`uv` IS THE FUTURE OF PYTHON PACKING!](https://www.youtube.com/watch?v=8UuW8o4bHbw)

#### 2.1.2 The ```handler.py``` Python Script File
To keep things streamlined, I consolidated all import statements, constants, and the AWS Lambda handler function into a single module—the code in `handler.py` is the real star here. Below is a breakdown of its structure:

##### 2.1.2.1 Import Statements
Here are the import statements you’ll need to include at the top of your Python script:

```python
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
```

##### 2.1.2.2 Constants
I love leveraging constants to keep code clear, maintainable, and future-proof.  Below are the essential constants you’ll want to include at the top of your Python script:

```python
# Confluent Cloud for Apache Flink Secrets Keys
ENVIRONMENT_ID = "environment.id"
FLINK_API_KEY = "flink.api.key"
FLINK_API_SECRET = "flink.api.secret"
FLINK_CLOUD = "flink.cloud"
FLINK_COMPUTE_POOL_ID = "flink.compute.pool.id"
FLINK_PRINCIPAL_ID = "flink.principal.id"
FLINK_REGION = "flink.region"
ORGANIZATION_ID = "organization.id"
```

##### 2.1.2.3 The Lambda Handler Function
The Lambda function serves as the entry point for your AWS Lambda application written in Python. It is a Python function that AWS Lambda invokes when your Lambda function is executed (i.e, invoked).  So, to put it another way, as my mom would say (yes, she was a programmer back in the day), this is where your Flink app’s life begins! 🚀

The code uses a basic signature for the handler function, which is required by AWS Lambda:

```python
def handler(event, context):
    """
    This AWS Lambda function is the main entry point for the Flink app.  It defines
    the Kafka sink table, reads from source tables, transforms the data, and writes
    to the sink.

    Arg(s):
        event (Dict)           :  The event data passed to the Lambda function.
        context (LambdaContext):  The metadata about the invocation, function, and 
                                  execution environment.

    Returns:
        statusCode with a message in the body: 
            200 for a successfully run of the function.
            400 for a missing required field.
            500 for a critical error.
    """
```

**The handler function** accepts two critical arguments:

- **event (Dict)** – Typically generated by AWS services (e.g., S3 or API Gateway). In this example, it’s the JSON object from Terraform that AWS Lambda receives.  
- **context (LambdaContext)** – An object holding details about the function’s invocation, configuration, and runtime environment.

As you’ll see when we walk through the code, the handler returns a **JSON-serializable dictionary**—that contains a `statusCode` and `body`—to track and communicate the success or failure of the deployment.

In the next sections, we’ll break down the handler function into nine parts to explain the logic and flow of the code.

###### 2.1.2.3.1 Part 1 of 9 of the Lambda Handler Function Code
The code snippet below sets up a logger to log messages at the INFO level. The logger is used to log messages to the AWS CloudWatch Logs service, which is a centralized logging service provided by AWS.

```python
    # Set up the logger.
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
```

###### 2.1.2.3.2 Part 2 of 9 of the Lambda Handler Function Code
The code snippet below checks that all required fields for the event exist. If any of the required fields are missing, the code logs an error message and returns a JSON object with a status code of 400 and an error message in the body.  The `catalog_name` field contains the name of the Confluent Cloud for Apache Flink catalog, the `database_name` field contains the name of the database in the catalog, and the `ccaf_secrets_path` field contains the path to the Confluent Cloud for Apache Flink secrets in AWS Secrets Manager.

```python
     # Check all required fields for the event exist.
    required_event_fields = ["catalog_name", "database_name", "ccaf_secrets_path"]
    for field in required_event_fields:
        if field not in event:
            logger.error(f"Missing required field: {field}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Missing required field: {field}'})
            }

    # Get the required fields from the event.
    catalog_name = event["catalog_name"]
    database_name = event["database_name"]
    ccaf_secrets_path = event["ccaf_secrets_path"]
```

###### 2.1.2.3.3 Part 3 of 9 of the Lambda Handler Function Code
The code snippet below gets the Confluent Cloud for Apache Flink secrets from AWS Secrets Manager using the `ccaf_secrets_path` field. If the secrets are successfully retrieved, the code creates a TableEnvironment with the Confluent Cloud for Apache Flink settings. If the secrets cannot be retrieved, the code logs an error message and returns a JSON object with a status code of 500 and an error message in the body.

```python
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
                .set_principal_id(settings[FLINK_PRINCIPAL_ID])
                .build()
        )
    except ClientError as e:
        logger.error("Failed to get secrets from the AWS Secrets Manager because of %s.", e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

> **Note:** _It is assumpted that you have already created the Confluent Cloud for Apache Flink secrets in AWS Secrets Manager when you ran the Terraform configuration in the [Apache Flink Kickstarter](https://github.com/j3-signalroom/apache_flink-kickstarter) Project.  If you have not, you can follow the instructions in the [README](https://github.com/j3-signalroom/apache_flink-kickstarter/blob/main/README.md#20-lets-get-started)._

###### 2.1.2.3.4 Part 4 of 9 of the Lambda Handler Function Code
The code snippet below sets the current catalog and database in the TableEnvironment. The code then gets the catalog from the TableEnvironment using the `catalog_name` field.

```python
    # The catalog name and database name are used to set the current catalog and database.
    tbl_env.use_catalog(catalog_name)
    tbl_env.use_database(database_name)
    catalog = tbl_env.get_catalog(catalog_name)
```

###### 2.1.2.3.5 Part 5 of 9 of the Lambda Handler Function Code
The code snippet below creates the Kafka sink table in the Confluent Cloud for Apache Flink catalog. The sink table is created with an Avro serialization format. The sink table has eight columns: `departure_airport_code`, `flight_number`, `email_address`, `departure_time`, `arrival_time`, `arrival_airport_code`, `confirmation_code`, and `airline`. The sink table is distributed by `departure_airport_code` and `flight_number` into one bucket. The sink table has an Avro key format and an Avro value format.

```python
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
```

###### 2.1.2.3.6 Part 6 of 9 of the Lambda Handler Function Code
The code snippet below gets the schema and columns from the airline table. The code then creates two tables: one for the SkyOne airline and one for the Sunset airline. The SkyOne table contains all columns from the airline table except for the excluded columns. The Sunset table contains all columns from the airline table except for the excluded columns.

```python
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
```

> **Note:** _It is assumpted that you have already created and filled with records the `airline.skyone_avro` and `airline.sunset_avro` Kafka topics when you played with the [Apache Flink Kickstarter](https://github.com/j3-signalroom/apache_flink-kickstarter) Project.  If you have not, you can follow the instructions in the [README](https://github.com/j3-signalroom/apache_flink-kickstarter/blob/main/java/README.md#21-avro-formatted-data)._

###### 2.1.2.3.7 Part 7 of 9 of the Lambda Handler Function Code
The code snippet below constructs a filter condition that ensures all columns specified in the flight_columns list are not null.   This type of functional programming code is commonly used in data streaming frameworks like Apache Flink or Apache Spark to filter out records that contain null values in any of the specified columns.

```python
    # Build a compound expression, ensuring each column is not null
    filter_condition = reduce(
        lambda accumulated_columns, current_column: accumulated_columns & col(current_column).is_not_null, flight_columns[1:], col(flight_columns[0]).is_not_null
    )
```

###### 2.1.2.3.8 Part 8 of 9 of the Lambda Handler Function Code
The code snippet below combines the two tables, the SkyOne table and the Sunset table, into one table. The combined table is filtered using the filter condition to ensure that all columns specified in the flight_columns list are not null.

```python
    # Combine the two tables.
    combined_airlines = (
        skyone_airline.union_all(sunset_airline)
        .alias(*flight_columns, "airline")
        .filter(filter_condition)
    )
```

###### 2.1.2.3.9 Part 9 of 9 of the Lambda Handler Function Code
The code snippet below inserts the combined record into the sink table. If the record is successfully inserted into the sink table, the code logs a message indicating that the data was processed and inserted successfully. If an error occurs during data insertion, the code logs an error message and returns a JSON object with a status code of 500 and an error message in the body.

```python
    # Insert the combined record into the sink table.
    try:
        # Supply a friendly statement name to easily search for it only in the Confluent Web UI.
        # However, the name is required to be unique within environment and region, so a UUID is
        # added.
        statement_name = "combined-flight-data-" + str(uuid.uuid4())
        tbl_env.get_config().set("client.statement-name", statement_name)

        # Execute the insert statement.
        table_result = combined_airlines.execute_insert(flight_avro_table_path.get_full_name())

        # Get the processed statement name.
        processed_statement_name = ConfluentTools.get_statement_name(table_result)
        success_message = f"Data processed and inserted successfully as: {processed_statement_name}"
        logger.info(success_message)
        return {
            'statusCode': 200,
            'body': json.dumps({'message': success_message})
        }
    except Exception as e:
        logger.error(f"An error occurred during data insertion: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

#### 2.1.3 The ```Dockerfile``` File
The Dockerfile is a text file that contains a series of commands that are executed by the Docker daemon to build a Docker image.  Here’s the Dockerfile you’ll need to create to package your Lambda function as a Docker container:

```dockerfile
FROM public.ecr.aws/lambda/python:3.11.2024.11.22.15

# Install Java 17
RUN yum clean all && \
    yum -y update && \
    yum -y install java-17-amazon-corretto-devel && \
    yum clean all

# Container metadata
LABEL maintainer=j3@thej3.com \
      description="Apache Flink Kickstarter Project, showcasing Confluent Clound for Apache Flink"

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Confluent Cloud for Apache Flink and other dependencies
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Copy the application code
COPY handler.py ${LAMBDA_TASK_ROOT}

# Set the handler
CMD ["handler.lambda_handler"]
```

#### 2.1.4 The ```requirements.txt``` File
The requirements.txt file contains a list of Python packages that are required by your Lambda function.  Here’s the requirements.txt file you’ll need to create to install the required Python packages:

```text
boto3>=1.35.90
confluent-flink-table-api-python-plugin>=1.20.42
setuptools>=65.5.1
lxml==4.9.2
```

## 2.2 The Terraform Configuration

**<TO BE COMPLETED>**

## 2.3 GitHub: The CI/CD Pipeline

**<TO BE COMPLETED>**

## 3.0 Conclusion

**<TO BE COMPLETED>**

## 4.0 Resources

**<TO BE COMPLETED>**