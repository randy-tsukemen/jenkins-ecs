# Jenkins ECS Architecture

## Overview

This document outlines the architecture for running Jenkins jobs at scale within a private VPC environment. The solution uses AWS ECS with EC2 instances and bridge networking mode to run Jenkins agents in containers, allowing us to scale to 100 concurrent jobs while managing the IP address constraints.

## Problem Statement

1. The company hosts GitLab server and Jenkins on EC2 within VPC-A
2. VPC-A only has 30 IP addresses available, limiting the ability to scale Jenkins jobs
3. The entire solution must remain within the company's internal network with no public internet connectivity
4. Need to run up to 100 concurrent jobs

## Solution Architecture

![Architecture Diagram](jenkins-ecs-architecture.png)

### Key IP Address Constraint and Solution

A key limitation we addressed: Amazon ECS Fargate uses awsvpc networking mode, where each task consumes a unique IP address. With only 30 IP addresses in VPC-A, we couldn't scale to 100 jobs using Fargate.

**Solution**: Use ECS on EC2 with bridge networking mode, where multiple containers can share a single EC2 instance's IP address.

### Components

1. **Jenkins Master**

   - Runs on an EC2 instance in VPC-A
   - Configured with the Amazon ECS plugin to launch agent tasks
   - Manages job scheduling and coordination

2. **Amazon ECS Cluster with EC2 Instances**

   - Consists of 5-10 EC2 instances in an Auto Scaling Group
   - Each EC2 instance can host multiple containers with a single IP address
   - Bridge networking mode allows up to 10-20 containers per instance
   - Auto-scaling configured to add/remove instances based on load

3. **Jenkins Agents**

   - Run as Docker containers on the EC2 instances
   - Custom image with all required tools pre-installed
   - Each container connects back to Jenkins Master

4. **Amazon ECR**

   - Private container registry for storing the Jenkins agent images
   - Accessible within the VPC without internet connectivity

5. **GitLab Server**
   - Existing GitLab server accessible to Jenkins Master and agents

### Network Architecture

1. **Bridge Networking**

   - Containers use bridge networking mode on EC2 instances
   - Multiple containers share the host's IP address
   - Dynamic port mapping for container communication

2. **VPC Endpoints**

   - Provide private connectivity to AWS services without internet
   - Required for ECR, ECS, S3, and CloudWatch services

3. **IP Address Management**
   - EC2 instances with bridge networking dramatically reduce IP usage
   - Estimated 5-10 EC2 instances (IP addresses) can support 100+ containers

### Scaling Strategy

1. **Initial Capacity**

   - Cluster starts with 2 EC2 instances
   - Each instance can host 10-20 containers

2. **Auto Scaling**

   - EC2 Auto Scaling Group adds/removes instances based on container demand
   - Configured to scale up to 10 instances for 100+ containers

3. **Concurrency**
   - Jenkins configured to execute jobs as they arrive, up to 100 concurrent jobs

## Implementation Steps

1. Install Amazon ECS plugin in Jenkins
2. Build and push the Jenkins agent Docker image to ECR
3. Create EC2 launch template and Auto Scaling Group for ECS instances
4. Configure Jenkins with ECS cloud configuration
5. Update Jenkinsfile to use ECS agents with bridge networking
6. Add Jenkinsfile to .gitignore

## Security Considerations

1. IAM Roles

   - EC2 instance role - permissions for container operations
   - Task execution role - minimum permissions for running containers
   - Task role - permissions needed for Jenkins agent operations

2. Security Groups

   - Restricted to allow only required traffic within VPC
   - No internet access required

3. Private Repositories
   - ECR repositories configured without public access
   - GitLab accessible only within the VPC

## Benefits

1. **IP Conservation** - Multiple containers share a single EC2 instance's IP address
2. **Scalability** - Can easily scale to 100+ concurrent jobs with just 5-10 IP addresses
3. **Isolation** - Each job runs in its own container
4. **Cost Optimization** - Efficiently utilize EC2 instances
5. **Simplified Management** - Auto Scaling Group handles the infrastructure scaling

## Conclusion

This architecture enables Jenkins to scale to 100 concurrent jobs while working within the constraints of a limited IP address range in VPC-A. It uses containerization with bridge networking to efficiently share network resources while maintaining isolation between jobs.
