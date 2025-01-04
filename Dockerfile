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