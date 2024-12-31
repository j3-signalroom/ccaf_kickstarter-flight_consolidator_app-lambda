# Confluent Cloud for Apache Flink (CCAF) Flight Consolidator App Lambda
This repository empowers the deployment of a robust [Flink Job Graph](https://github.com/j3-signalroom/j3-techstack-lexicon/blob/main/apache-flink-glossary.md#jobgraph) to [Confluent Cloud for Apache Flink (CCAF)](https://docs.confluent.io/cloud/current/flink/overview.html) , enabling seamless and continuous real-time streaming. The [Flink Job Graph](https://github.com/j3-signalroom/j3-techstack-lexicon/blob/main/apache-flink-glossary.md#jobgraph) meticulously ingests flight data from the `airline.sunset_avro` and `airline.skyone_avro` Kafka topics, standardizing and unifying the information into a single, consolidated `airline.flight_avro` Kafka topic. By leveraging advanced stream processing capabilities, this deployment ensures high scalability, data consistency, and reliability, providing organizations with a powerful foundation for actionable flight analytics and insightful decision-making.

---

**Table of Contents**

<!-- toc -->
+ [1.0 Let's get started!](#10-lets-get-started)
+ [2.0 Visualizing the Terraform Configuration](#20-visualizing-the-terraform-configuration)
<!-- tocstop -->

---

> _Please run the [**`AvroDataGeneratorApp`**](https://github.com/j3-signalroom/apache_flink-kickstarter/blob/main/java/README.md) first to generate the `airline.sunset_avro` and `airline.skyone_avro` Kafka topics before running this application._

---

## 1.0 Let's get started!
1. Take care of the cloud and local environment prequisities listed below:
    > You need to have the following cloud accounts:
    > - [AWS Account](https://signin.aws.amazon.com/) *with SSO configured*
    >  [`aws2-wrap` utility](https://pypi.org/project/aws2-wrap/#description)

    > You need to have the following installed on your local machine:
    > - [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

2. Clone the repo:
    ```bash
    git clone https://github.com/j3-signalroom/ccaf_kickstarter-flight_consolidator_app-lambda.git
    ```

3. **Navigate to the Root Directory**: Open your Terminal and navigate to the root folder of the `ccaf_kickstarter-flight_consolidator_app-lambda/` repository that you have cloned. You can do this by executing:

   ```bash
   cd path/to/ccaf_kickstarter-flight_consolidator_app-lambda/
   ```

   Replace `path/to/` with the actual path where your repository is located.

4. **Run the Script to Publish (Create) or Unpublish (Delete) the ECR Repository:**  Execute the `build-publish-lambda.sh` script to create an AWS Elastic Container Registry (ECR) repository, build the AWS Lambda Docker container, and publish it to the newly created ECR repository. This will make the container image available for future deployments.

    Use the following command format:

    ```bash
    scripts/build-publish-lambda.sh <create | delete> --profile=<SSO_PROFILE_NAME>
    ```

5. **Replace Argument Placeholders:**
   - `<create | delete>`: Specify either `create` to create the ECR repository or `delete` to remove it.
   - `<SSO_PROFILE_NAME>`: Replace this with your AWS Single Sign-On (SSO) profile name, which identifies your hosted AWS infrastructure.

    For example, to create the ECR repository, use the following command:
    ```bash
    scripts/build-publish-lambda.sh create --profile=my-aws-sso-profile
    ```
    Replace `my-aws-sso-profile` with your actual AWS SSO profile name.

6. **Run the Script to Create or Destroy the Terraform Configuration:**  Execute the `run-terraform-locally.sh` script to create the IAM Policy and Role for the Lambda, and then invoke (run) the Lambda.

    Use the following command format:

    ```bash
    scripts/run-terraform-locally.sh <create | delete> --profile=<SSO_PROFILE_NAME> --catalog-name=<CATALOG_NAME> --database-name=<DATABASE_NAME> --ccaf-secrets-path=<CCAF_SECRETS_PATH>"
    ```

7. **Replace Argument Placeholders:**
   - `<create | delete>`: Specify either `create` to create the ECR repository or `delete` to remove it.
   - `<SSO_PROFILE_NAME>`: Replace this with your AWS Single Sign-On (SSO) profile name, which identifies your hosted AWS infrastructure.
   - `<CATALOG_NAME>`: Replace this with the name of your Flink catalog.
   - `<DATABASE_NAME>`: Replace this with the name of your Flink database.
   - `<CCAF_SECRETS_PATH>`: Replace this with the path to the Confluent Cloud for Apache Flink (CCAF) AWS Secrets Manager secrets.

    For example, to create the IAM Policy and Role for the Lambda, and then invoke (run) the Lambda, use the following command:
    ```bash
    scripts/run-terraform-locally.sh create --profile=my-aws-sso-profile --catalog-name=flink_kickstarter --database-name=flink_kickstarter --ccaf-secrets-path="/confluent_cloud_resource/flink_kickstarter/flink_compute_pool"
    ```
    Replace `my-aws-sso-profile` with your actual AWS SSO profile name, `flink_kickstart` Flink catalog (Environment), `flink_kickstart` Flink database (Kafka Cluster) and the `/confluent_cloud_resource/flink_kickstarter/flink_compute_pool` AWS Secrets Manager secrets path.

8. Or, to run the similiar script from GitHub, follow these steps:

    a. Deploy the Repository: Ensure that you have cloned or forked the repository to your GitHub account.

    b. Set Required Secrets and Variables: Before running any of the GitHub workflows provided in the repository, you must define at least the `AWS_DEV_ACCOUNT_ID` variable (which should contain your AWS Account ID for your development environment). To do this:

    - Go to the Settings of your cloned or forked repository in GitHub.

    - Navigate to **Secrets and Variables > Actions**.

    - Add the `AWS_DEV_ACCOUNT_ID` and any other required variables or secrets.

    c. Navigate to the **Actions Page**:

    - From the cloned or forked repository on GitHub, click on the **Actions tab**.

    d. **Select and Run the Deploy Workflow**:

    - Find the **Deploy** workflow link on the left side of the **Actions** page and click on it.

        ![github-actions-workflows-screenshot](.blog/images/github-actions-screenshot.png)

    - On the **Deploy** workflow page, click the **Run workflow** button.

    - A workflow dialog box will appear. Fill in the necessary details and click **Run workflow** to initiate the building and publishing the Lambda docker container to ECR, to create the IAM Policy and Role for the Lambda, and then invoke (run) the Lambda.

        ![github-deploy-workflow-screenshot](.blog/images/github-run-deploy-workflow-screenshot.png)

By following these steps, you will set up the necessary infrastructure to build and deploy the **Flight Consolidator Confluent Cloud for Apache Flink App**!

## 2.0 Visualizing the Terraform Configuration
Below is the Terraform visualization of the Terraform configuration.  It shows the resources and their dependencies, making the infrastructure setup easier to understand.

![Terraform Visulization](.blog/images/terraform-visualization.png)

> **To fully view the image, open it in another tab on your browser to zoom in.**

When you update the Terraform Configuration, to update the Terraform visualization, use the [`terraform graph`](https://developer.hashicorp.com/terraform/cli/commands/graph) command with [Graphviz](https://graphviz.org/) to generate a visual representation of the resources and their dependencies.  To do this, run the following command:

```bash
terraform graph | dot -Tpng > .blog/images/terraform-visualization.png
```