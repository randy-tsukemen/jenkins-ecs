#!/bin/bash
set -e

# This script installs and configures the Amazon ECS plugin for Jenkins with EC2-based agents

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Jenkins plugins
echo "Installing Jenkins plugins..."
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_TOKEN="your-jenkins-api-token"  # Replace with actual token

# Download and install Jenkins CLI
wget ${JENKINS_URL}/jnlpJars/jenkins-cli.jar

# Install required plugins
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_TOKEN} install-plugin amazon-ecs credentials amazon-ecr workflow-aggregator

# Wait for plugins to be installed
echo "Waiting for plugins to be installed..."
sleep 30

# Restart Jenkins to apply plugin changes
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_TOKEN} safe-restart

echo "Waiting for Jenkins to restart..."
sleep 60

# Configure AWS credentials in Jenkins
echo "Configuring AWS credentials..."
# This part typically requires using the Jenkins API or the UI
# Here we provide instructions for manual configuration
echo "Please configure AWS credentials in Jenkins:"
echo "1. Go to Manage Jenkins > Manage Credentials"
echo "2. Add AWS credentials with ID 'aws-credentials-id'"

# Configure ECS plugin settings
echo "Copying ECS plugin configuration..."
sed -i "s/your-region/${AWS_REGION}/g" jenkins-ecs-plugin-config.xml
sed -i "s/account-id/${AWS_ACCOUNT_ID}/g" jenkins-ecs-plugin-config.xml
sed -i "s/jenkins-master-private-ip/${JENKINS_MASTER_IP}/g" jenkins-ecs-plugin-config.xml
cp jenkins-ecs-plugin-config.xml /var/lib/jenkins/clouds.xml

# Restart Jenkins again to apply cloud configuration
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_TOKEN} safe-restart

echo "Jenkins ECS plugin configuration completed for EC2-based agents with bridge networking."
echo "Please verify the configuration in the Jenkins UI:"
echo "Manage Jenkins > Manage Nodes and Clouds > Configure Clouds"
echo ""
echo "IMPORTANT: Ensure your Jenkinsfile specifies 'networkMode: bridge' in the ECS agent configuration." 