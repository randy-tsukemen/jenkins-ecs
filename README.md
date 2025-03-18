# Jenkins on AWS ECS - High-Scale Deployment

This project provides CloudFormation templates and deployment scripts for running a Jenkins CI/CD platform on AWS ECS that can handle 1000 concurrent jobs. The architecture follows AWS best practices for scalability, availability, and security.

## Architecture Overview

The solution consists of:

- **Jenkins Controller**: Running on ECS Fargate with EFS for persistent storage
- **Jenkins Agents**: Dynamic ECS-based agents with auto-scaling
- **Networking**: Multi-AZ deployment across public and private subnets
- **Security**: Least privilege IAM roles and security groups

Refer to the `JENKINS-ECS-DEPLOYMENT-GUIDE.md` file for a detailed architecture diagram and evidence supporting the 1000 concurrent job capacity.

## Features

- **Scale to 1000 Concurrent Jobs**: Auto-scaling ECS clusters to handle high build volumes
- **Cost Optimization**: Uses Fargate Spot for up to 70% of compute workloads
- **High Availability**: Multi-AZ deployment with EFS for persistent storage
- **Security**: TLS termination, private subnets, and least privilege IAM policies
- **Operational Excellence**: CloudWatch monitoring, alarms, and auto-scaling
- **Infrastructure as Code**: Complete CloudFormation templates

## Scalability Evidence

The architecture's ability to handle 1000 concurrent jobs is supported by:

- **Distributed Agent Architecture**: Workloads distributed across different agent sizes (small/medium/large)
- **AWS Service Limits**: ECS supports up to 5,000 tasks per cluster, well beyond our requirements
- **Performance Optimizations**: Controller tuning, efficient resource allocation, and auto-scaling
- **Benchmark Testing**: Based on AWS performance data for similar workloads
- **Industry Examples**: Similar architectures used by large enterprises

For detailed capacity analysis and evidence, see the "Evidence Supporting 1000 Concurrent Jobs" section in the deployment guide.

## Scalability Demonstration

For teams who want to validate the scaling capabilities of this architecture, we've provided a detailed demonstration guide that walks through:

- Setting up test jobs to simulate concurrent workloads
- Observing real-time auto-scaling of ECS agents
- Measuring scale-up and scale-down performance
- Extrapolating results to 1000-job capacity

Follow the instructions in `SCALABILITY-DEMONSTRATION-GUIDE.md` to run a controlled test with 100 concurrent jobs and observe the system's scaling behavior. The guide includes monitoring tools, test job scripts, and analysis methods.

## Batch Workload Optimization

**New**: For organizations running large-scale tests periodically (e.g., 10 times per week) with minimal usage during other periods, see `COST-OPTIMIZATION-FOR-BATCH-WORKLOADS.md` for:

- Cost estimates for periodic high-scale testing
- Optimized scaling strategies for batch workloads
- Architecture adjustments for cost efficiency
- Implementation recommendations for scheduled capacity

**Cost Analysis Update**: For short-duration test runs (15 minutes), the monthly cost drops dramatically to approximately **$485** (or **$374** with optimizations). See the cost document for the detailed breakdown.

This optimized approach can reduce costs by up to 87% compared to longer test runs while maintaining performance during test execution.

## Files in This Repository

- `JENKINS-ECS-DEPLOYMENT-GUIDE.md`: Comprehensive guide with best practices
- `COST-OPTIMIZATION-FOR-BATCH-WORKLOADS.md`: Guidance for periodic high-scale testing
- `SCALABILITY-DEMONSTRATION-GUIDE.md`: Step-by-step guide for testing scalability
- `scaling-dashboard.json`: CloudWatch dashboard for monitoring scaling
- `VPC-CONNECTIVITY-AND-EC2-CONTROLLER.md`: Guide for VPC connectivity options and EC2-based Jenkins controller
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
