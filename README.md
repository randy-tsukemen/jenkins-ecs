# Jenkins ECS Solution

This project provides a scalable Jenkins solution using Amazon ECS with EC2 instances and bridge networking to run Jenkins agents in containers, enabling 100+ concurrent jobs while conserving IP addresses in a private VPC.

## Problem Statement

1. VPC-A hosts GitLab server and Jenkins on EC2 using IPv4 communication
2. VPC-A is limited to only 30 IP addresses
3. Jenkins needs to scale to run 100 concurrent jobs
4. All communication must remain within the company's internal network

## IP Address Constraint and Solution

**Key Challenge**: Initially, we considered using ECS Fargate, but Fargate tasks require awsvpc networking mode where each task needs its own IP address. With only 30 IPs available, this approach wouldn't scale to 100 jobs.

**Solution**: Use ECS on EC2 with bridge networking mode, where multiple containers can share a single EC2 instance's IP address, allowing us to run 100+ containers with only 5-10 IP addresses.

## Solution Overview

The solution uses AWS ECS with EC2 instances using bridge networking to run Jenkins agents as Docker containers:

- **Jenkins Master**: EC2 instance in VPC-A configured with the ECS plugin
- **ECS Cluster**: EC2-based cluster with Auto Scaling Group (5-10 instances)
- **Container Networking**: Bridge mode allowing 10-20 containers per EC2 instance
- **Container Registry**: Private ECR repository for Jenkins agent images
- **VPC Endpoints**: For private AWS service access without internet connectivity

## Architecture Benefits

1. **IP Conservation**: Multiple containers share a single EC2 instance's IP address
2. **Scalability**: Easily scales to 100+ concurrent jobs with only 5-10 IP addresses
3. **Isolation**: Each job runs in its own container
4. **Security**: No public internet access required
5. **Cost Efficiency**: Efficiently utilize EC2 instances with multiple containers

## Project Structure

- `Dockerfile`: Defines the Jenkins agent container image
- `entrypoint.sh`: Container startup script
- `jenkins-ecs-config.tf`: Terraform configuration for ECS resources
- `vpc-endpoints.tf`: Terraform configuration for VPC endpoints
- `variables.tf`: Terraform variables
- `jenkins-ecs-plugin-config.xml`: Jenkins ECS plugin configuration
- `configure-jenkins-ecs.sh`: Script to install and configure Jenkins plugins
- `jenkins-ecs-architecture.md`: Detailed architecture documentation

## Prerequisites

- Existing VPC with GitLab and Jenkins Master
- AWS CLI installed and configured
- Terraform installed
- Docker installed
- Jenkins Admin access

## Setup Instructions

### 1. Configure Terraform Variables

Edit `variables.tf` with your specific values:

- AWS region
- VPC ID
- Subnet IDs
- ECS AMI ID (Amazon ECS-optimized AMI for your region)
- CIDR blocks

### 2. Deploy Infrastructure with Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 3. Build and Push Jenkins Agent Docker Image

```bash
aws ecr get-login-password --region your-region | docker login --username AWS --password-stdin account-id.dkr.ecr.your-region.amazonaws.com
docker build -t jenkins-agent .
docker tag jenkins-agent:latest account-id.dkr.ecr.your-region.amazonaws.com/jenkins-agent:latest
docker push account-id.dkr.ecr.your-region.amazonaws.com/jenkins-agent:latest
```

### 4. Configure Jenkins

1. Install the Amazon ECS plugin
2. Configure Jenkins ECS cloud with bridge network mode (use the provided script)
3. Update Jenkinsfile to use ECS agents with bridge networking

## Usage

When Jenkins jobs are triggered, they will automatically use the ECS-based agents, with the ECS cluster's Auto Scaling Group adding EC2 instances as needed to support up to 100 concurrent jobs.

## Maintenance

- Update Docker images regularly with security patches
- Monitor ECS service for performance and scaling events
- Review Jenkins logs for any connectivity issues
- Monitor EC2 instance utilization and adjust instance types if needed

## Additional Resources

- [Jenkins ECS Plugin Documentation](https://plugins.jenkins.io/amazon-ecs/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_instances.html)
- [AWS PrivateLink Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html)
