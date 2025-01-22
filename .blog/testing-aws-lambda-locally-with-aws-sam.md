# Testing AWS Lambda locally using AWS SAM
AWS SAM (Serverless Application Model) is an open-source framework provided by AWS to simplify the deployment and testing of serverless applications. In this post, I will show you how to test AWS Lambda functions locally using AWS SAM.  Because what makes AWS SAM unique is that it allows you to test your serverless applications locally before deploying them to the cloud. This can save you a lot of time and money by catching bugs early in the development process.

AWS SAM Key Features:
* Local Testing and Debugging
* Simplified Defintion of Serverless Resources
* CloudFormation Compatibility
* Simplified Development and Deployment
* Support for Container Images


Once we have the application written, we can use the AWS SAM CLI to test the application locally. The AWS SAM CLI is a command-line tool that provides an environment for testing and debugging serverless applications locally. It allows you to invoke Lambda functions, test API Gateway endpoints, and generate sample events for testing.  Now, let's see how we can use the AWS SAM CLI to test our Lambda function locally.


Define the Template.yaml file that describes the AWS resources in your serverless application. The template file is written in YAML or JSON and contains the following sections:

### Step 1 of 5:  Resources
FlightConsolidatorLambda: This is the logical name for the resource being defined. It represents a serverless function.
Type: AWS::Serverless::Function: This is the type of resource being defined. In this case, it is a serverless function.

This YAML defines a resource for deployment using AWS SAM (Serverless Application Model). Here's a breakdown of its key components:

### **Resource**
- **`FlightConsolidatorLambda`**: This is the logical name for the resource being defined. It represents a serverless function.

---

### **Type**
- **`AWS::Serverless::Function`**: This specifies that the resource is a Lambda function managed under AWS SAM.

---

### **Properties**
1. **`PackageType: Image`**:
   - Indicates that the Lambda function is deployed as a container image rather than as a traditional ZIP archive.

2. **`ImageConfig`**:
   - **`Command`**: Defines the entry point command for the Lambda container image, here specified as `handler.lambda_handler`. This means the Lambda function will invoke the `lambda_handler` function in the `handler` module.

3. **`MemorySize: 1024`**:
   - Allocates 1024 MB (1 GB) of memory to the Lambda function. A higher memory allocation can improve performance but increases cost.

4. **`Timeout: 90`**:
   - Sets the maximum execution time for the function to 90 seconds. After this time, the function will terminate, even if it hasn’t completed execution.

---

### **Metadata**
The `Metadata` section provides additional information to guide the SAM deployment process. It includes:
1. **`Dockerfile`**:
   - Specifies the path to the Dockerfile for building the container image:  
     `/Users/jeffreyjonathanjennings/j3/code_spaces/ccaf_kickstarter-flight_consolidator_app-lambda/Dockerfile`.

2. **`DockerContext`**:
   - Points to the directory containing the application source code, Dockerfile, and other relevant files:  
     `/Users/jeffreyjonathanjennings/j3/code_spaces/ccaf_kickstarter-flight_consolidator_app-lambda`.

3. **`DockerTag`**:
   - Sets the tag for the Docker image as `Latest`. This is a common tag for identifying the most recent build of the image.

---
