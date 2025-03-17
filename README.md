# Jenkins on AWS ECS - High-Scale Deployment

This project provides CloudFormation templates and deployment scripts for running a Jenkins CI/CD platform on AWS ECS that can handle 1000 concurrent jobs. The architecture follows AWS best practices for scalability, availability, and security.

## Architecture Overview

The solution consists of:

- **Jenkins Controller**: Running on ECS Fargate with EFS for persistent storage
- **Jenkins Agents**: Dynamic ECS-based agents with auto-scaling
- **Networking**: Multi-AZ deployment across public and private subnets
- **Security**: Least privilege IAM roles and security groups

![Architecture Diagram](https://d2908q01vomqb2.cloudfront.net/7719a1c782a1ba91c031a682a0a2f8658209adbf/2019/10/20/Picture1.png)

## Features

- **Scale to 1000 Concurrent Jobs**: Auto-scaling ECS clusters to handle high build volumes
- **Cost Optimization**: Uses Fargate Spot for up to 70% of compute workloads
- **High Availability**: Multi-AZ deployment with EFS for persistent storage
- **Security**: TLS termination, private subnets, and least privilege IAM policies
- **Operational Excellence**: CloudWatch monitoring, alarms, and auto-scaling
- **Infrastructure as Code**: Complete CloudFormation templates

## Files in This Repository

- `JENKINS-ECS-DEPLOYMENT-GUIDE.md`: Comprehensive guide with best practices
- `jenkins-controller-service.yaml`: CloudFormation template for Jenkins controller
- `jenkins-agent-cluster.yaml`: CloudFormation template for agent clusters
- `deploy.sh`: Deployment script to simplify installation
- `README.md`: This file

## Prerequisites

Before deployment, you need:

1. AWS CLI installed and configured
2. An existing VPC with public and private subnets
3. An SSL certificate in AWS Certificate Manager
4. Permissions to create resources (IAM, ECS, EFS, etc.)

## Quick Start

1. Clone this repository:

```
git clone https://github.com/yourusername/jenkins-ecs.git
cd jenkins-ecs
```

2. Make the deployment script executable:

```
chmod +x deploy.sh
```

3. Run the deployment script with your parameters:

```
./deploy.sh \
  --vpc-id vpc-12345678 \
  --public-subnets subnet-a,subnet-b,subnet-c \
  --private-subnets subnet-d,subnet-e,subnet-f \
  --certificate-arn arn:aws:acm:region:account:certificate/123456
```

4. Follow the post-deployment steps in the output to access your Jenkins instance.

## Configuration

After deployment, you'll need to:

1. Set up Jenkins with the initial admin password
2. Install the ECS plugin and configure agent templates
3. Configure job queues and labels for workload distribution

Refer to `JENKINS-ECS-DEPLOYMENT-GUIDE.md` for detailed configuration instructions.

## Scaling Considerations

This solution is designed to scale to 1000 concurrent jobs by:

- Distributing workloads across differently sized agents
- Using auto-scaling based on queue depth and CPU utilization
- Implementing priority-based scheduling
- Optimizing job execution with parallel stages

## Cost Optimization

To optimize costs:

- Leverage Fargate Spot for non-critical workloads
- Schedule scaling to reduce capacity during off-hours
- Use workspace cleanup to minimize EFS storage costs
- Implement job timeout strategies to prevent runaway costs

## Security

The deployment implements security best practices:

- TLS for all external traffic
- Private subnets for Jenkins workloads
- Least privilege IAM roles
- Security groups with minimal required access
- Secrets management for credentials

## Monitoring

The solution includes:

- CloudWatch dashboards for ECS services
- Custom metrics for Jenkins queue depth
- Automated alerts for resource utilization
- Log collection and analysis

## Support

For issues, questions, or contributions, please open an issue in this repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
