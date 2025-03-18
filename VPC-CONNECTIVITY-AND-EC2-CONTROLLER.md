# VPC Connectivity and EC2 Jenkins Controller

This document provides guidance on:

1. Connecting two VPCs without using VPC peering or public internet
2. Deploying the Jenkins controller on an EC2 instance instead of an ECS task

## Connecting Two VPCs Without Peering or Public Internet

When you need to connect your Jenkins VPC with another VPC (such as one containing your build environments or deployment targets), there are several options beyond traditional VPC peering:

### Option 1: AWS Transit Gateway

AWS Transit Gateway acts as a network transit hub that connects all your VPCs, AWS accounts, and on-premises networks.

#### Configuration Steps:

1. **Create Transit Gateway**:

   ```bash
   aws ec2 create-transit-gateway \
     --description "Jenkins Network Hub" \
     --options AmazonSideAsn=64512
   ```

2. **Attach VPCs to Transit Gateway**:

   ```bash
   # Attach Jenkins VPC
   aws ec2 create-transit-gateway-vpc-attachment \
     --transit-gateway-id tgw-12345678 \
     --vpc-id vpc-xxxxxxxx \
     --subnet-ids subnet-11111111 subnet-22222222

   # Attach Target VPC
   aws ec2 create-transit-gateway-vpc-attachment \
     --transit-gateway-id tgw-12345678 \
     --vpc-id vpc-yyyyyyyy \
     --subnet-ids subnet-33333333 subnet-44444444
   ```

3. **Update Route Tables**:
   - In Jenkins VPC route table:
     ```
     Destination: Target VPC CIDR (e.g., 10.1.0.0/16)
     Target: Transit Gateway ID (tgw-12345678)
     ```
   - In Target VPC route table:
     ```
     Destination: Jenkins VPC CIDR (e.g., 10.0.0.0/16)
     Target: Transit Gateway ID (tgw-12345678)
     ```

#### Advantages:

- Scalable to thousands of VPCs
- Centralized connection point
- Support for transitive routing
- Built-in high availability

#### Considerations:

- Cost: Hourly charges for the Transit Gateway plus data processing fees
- Slightly higher latency than direct VPC peering

### Option 2: AWS PrivateLink (VPC Endpoint Services)

Use AWS PrivateLink to create private connections between VPCs for specific services.

#### Configuration Steps:

1. **Create a Network Load Balancer in the Service VPC**:

   ```bash
   aws elbv2 create-load-balancer \
     --name jenkins-internal-nlb \
     --type network \
     --subnet-mappings SubnetId=subnet-11111111 \
     --scheme internal
   ```

2. **Create VPC Endpoint Service**:

   ```bash
   aws ec2 create-vpc-endpoint-service \
     --acceptance-required false \
     --network-load-balancer-arns arn:aws:elasticloadbalancing:region:account:loadbalancer/net/jenkins-internal-nlb/xxxxxxxx
   ```

3. **Create VPC Endpoint in the Consumer VPC**:
   ```bash
   aws ec2 create-vpc-endpoint \
     --vpc-id vpc-yyyyyyyy \
     --service-name com.amazonaws.vpce.region.vpce-svc-xxxxxxxxxxxxxxxxx \
     --vpc-endpoint-type Interface \
     --subnet-ids subnet-33333333 \
     --security-group-ids sg-zzzzzzzz
   ```

#### Advantages:

- Service-level connectivity (more granular control)
- No route table modifications needed
- Simpler security model
- Highly available

#### Considerations:

- Connection is established to specific services, not entire VPC
- Requires NLB or Gateway Load Balancer
- Slightly more complex setup

### Option 3: AWS Site-to-Site VPN through Transit Gateway

You can establish VPN connections between VPCs using Transit Gateway:

#### Configuration Steps:

1. **Create Transit Gateway** (as shown in Option 1)

2. **Create Customer Gateways for each VPC**:

   ```bash
   # Create Customer Gateways in both VPCs
   aws ec2 create-customer-gateway \
     --bgp-asn 65000 \
     --type ipsec.1 \
     --ip-address elastic-ip-address-1

   aws ec2 create-customer-gateway \
     --bgp-asn 65001 \
     --type ipsec.1 \
     --ip-address elastic-ip-address-2
   ```

3. **Create and Configure VPN Connections**:
   ```bash
   aws ec2 create-vpn-connection \
     --customer-gateway-id cgw-12345678 \
     --transit-gateway-id tgw-12345678 \
     --type ipsec.1 \
     --options StaticRoutesOnly=true
   ```

#### Advantages:

- Uses encrypted communication
- Works across AWS regions
- Lower cost than Direct Connect
- Ideal for less-critical workloads

#### Considerations:

- Higher latency than direct connectivity
- Bandwidth limitations (max 1.25 Gbps per tunnel)
- Subject to internet conditions

## Deploying Jenkins Controller on EC2 Instance

While our original architecture used ECS for the Jenkins controller, here's how to deploy it on an EC2 instance instead while still using ECS for agents.

### EC2 Jenkins Controller Architecture

1. **EC2 Instance** (controller):

   - Amazon Linux 2 or Ubuntu LTS
   - t3.xlarge (4 vCPU, 16GB RAM) recommended for 1000 job support
   - EBS volumes:
     - Root volume: 20GB gp3
     - Data volume: 100GB gp3 for Jenkins home

2. **Networking**:

   - Placed in a private subnet
   - Accessed via Application Load Balancer in public subnet
   - Security groups for controlled access

3. **High Availability**:
   - Multi-AZ setup with standby instance (optional)
   - EBS snapshots for backups
   - Amazon EFS for shared JENKINS_HOME (recommended)

### Implementation Steps

#### 1. Create EC2 Instance for Jenkins Controller

Create a CloudFormation template for the EC2 instance:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Resources:
  JenkinsSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for Jenkins controller
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: !Ref ALBSecurityGroup
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          SourceSecurityGroupId: !Ref BastionSecurityGroup

  JenkinsEFSMountTarget:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref JenkinsEFS
      SecurityGroups:
        - !Ref EFSSecurityGroup
      SubnetId: !Ref PrivateSubnet1

  JenkinsController:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.xlarge
      ImageId: !Ref LatestAmiId
      SubnetId: !Ref PrivateSubnet1
      SecurityGroupIds:
        - !Ref JenkinsSecurityGroup
      BlockDeviceMappings:
        - DeviceName: /dev/xvda
          Ebs:
            VolumeSize: 20
            VolumeType: gp3
            DeleteOnTermination: true
        - DeviceName: /dev/sdf
          Ebs:
            VolumeSize: 100
            VolumeType: gp3
            DeleteOnTermination: false
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          # Update system
          yum update -y

          # Install required packages
          yum install -y amazon-efs-utils java-11-amazon-corretto docker
          systemctl enable docker
          systemctl start docker

          # Mount EFS for Jenkins home
          mkdir -p /var/jenkins_home
          echo "${JenkinsEFS}:/ /var/jenkins_home efs _netdev,tls,iam 0 0" >> /etc/fstab
          mount -a

          # Install Jenkins
          wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
          rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
          yum install -y jenkins

          # Configure Jenkins
          cat > /etc/sysconfig/jenkins <<EOF
          JENKINS_HOME=/var/jenkins_home
          JENKINS_USER=jenkins
          JENKINS_PORT=8080
          JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dhudson.model.ParametersAction.keepUndefinedParameters=true -Dorg.jenkinsci.plugins.durabletask.BourneShellScript.HEARTBEAT_CHECK_INTERVAL=300"
          EOF

          # Set permissions
          chown -R jenkins:jenkins /var/jenkins_home

          # Install AWS CLI v2
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          ./aws/install

          # Start Jenkins
          systemctl enable jenkins
          systemctl start jenkins

      Tags:
        - Key: Name
          Value: jenkins-controller
```

#### 2. Configure EC2 Instance for ECS Agent Management

After Jenkins is installed, configure it to use ECS for agent provisioning:

1. SSH into the EC2 instance:

   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-private-ip
   ```

2. Install the required Jenkins plugins:

   ```bash
   jenkins-plugin-cli --plugins "amazon-ecs:1.39 credentials:2.6.1 docker-workflow:1.26"
   ```

3. Configure Jenkins for AWS ECS (via System Configuration):

   - Navigate to Manage Jenkins > Configure System
   - Add Amazon ECS cloud configuration:
     - Name: `ecs-agents`
     - Amazon ECS Credential: (Create AWS credentials with proper ECS permissions)
     - ECS Cluster: `jenkins-agent-cluster`
     - ECS Region: `us-east-1` (or your region)

4. Configure agent templates for small, medium, and large agents as per our original design

#### 3. EC2 Controller-Specific Security Configuration

1. **IAM Role for EC2 Instance**:

   ```yaml
   JenkinsInstanceProfile:
     Type: AWS::IAM::InstanceProfile
     Properties:
       Roles:
         - !Ref JenkinsIAMRole

   JenkinsIAMRole:
     Type: AWS::IAM::Role
     Properties:
       AssumeRolePolicyDocument:
         Version: "2012-10-17"
         Statement:
           - Effect: Allow
             Principal:
               Service: ec2.amazonaws.com
             Action: sts:AssumeRole
       ManagedPolicyArns:
         - arn:aws:iam::aws:policy/AmazonECR-FullAccess
         - arn:aws:iam::aws:policy/AmazonECS-FullAccess
       Policies:
         - PolicyName: JenkinsEFSAccess
           PolicyDocument:
             Version: "2012-10-17"
             Statement:
               - Effect: Allow
                 Action:
                   - elasticfilesystem:ClientMount
                   - elasticfilesystem:ClientWrite
                 Resource: !GetAtt JenkinsEFS.Arn
   ```

2. **Security Group Configuration**:
   - Allow inbound traffic from ALB on port 8080
   - Allow outbound traffic to ECS endpoints
   - Allow NFS traffic (port 2049) to EFS mount targets

### Comparison with ECS Controller Deployment

| Aspect          | EC2 Controller                         | ECS Controller                   |
| --------------- | -------------------------------------- | -------------------------------- |
| **Deployment**  | Manual or CloudFormation               | Containerized, managed by ECS    |
| **Updates**     | Manual OS patching needed              | Container image updates          |
| **Scalability** | Vertical only (instance sizing)        | Both vertical and horizontal     |
| **HA Setup**    | More complex, needs standby instance   | Built-in with ECS service        |
| **Management**  | Full control of host environment       | Limited to container environment |
| **Cost**        | Potentially lower for stable workloads | Pay for Fargate resource usage   |
| **Security**    | More security responsibilities         | Reduced attack surface           |

## Integration with ECS Agents

The EC2-based Jenkins controller still communicates with ECS agents:

1. **Controller Configuration**:

   - The EC2 Jenkins controller needs IAM permissions to call ECS APIs
   - The Amazon ECS plugin uses the AWS SDK to provision agents

2. **Networking Requirements**:

   - Both the EC2 instance and ECS tasks must have network connectivity
   - If in separate VPCs, use one of the VPC connectivity options above
   - Security groups must allow traffic between controller and agents

3. **Agent Provisioning Flow**:
   1. Jenkins schedules a job requiring an agent
   2. The ECS plugin uses AWS SDK to call ECS RunTask API
   3. ECS launches the agent container in the specified subnet
   4. Agent establishes JNLP connection back to controller
   5. Job executes on the agent
   6. Agent terminates after idle timeout

## Complete Architecture Diagram

```
┌─────────────────────────────────────────┐      ┌─────────────────────────────────────────┐
│            Jenkins VPC                  │      │         Target/Build VPC                │
│                                         │      │                                         │
│  ┌────────────┐     ┌────────────┐      │      │   ┌─────────────┐    ┌─────────────┐   │
│  │   Public   │     │   Private  │      │      │   │  Private    │    │ Private     │   │
│  │   Subnet   │     │   Subnet   │      │      │   │  Subnet     │    │ Subnet      │   │
│  │            │     │            │      │      │   │             │    │             │   │
│  │ ┌────────┐ │     │ ┌────────┐ │      │      │   │ ┌─────────┐ │    │ ┌─────────┐ │   │
│  │ │   ALB  │─┼─────┼▶│  EC2   │ │      │      │   │ │ ECS     │ │    │ │ Build   │ │   │
│  │ └────────┘ │     │ │Jenkins │◀┐     │      │   │ │ Agents  │ │    │ │Resources│ │   │
│  │            │     │ └────────┘ │     │      │   │ └─────────┘ │    │ └─────────┘ │   │
│  └────────────┘     │            │     │      │   │             │    │             │   │
│                     │ ┌────────┐ │     │      │   └─────────────┘    └─────────────┘   │
│                     │ │   EFS  │ │     │      │                                         │
│                     │ └────────┘ │     │      │                                         │
│                     └────────────┘     │      │                                         │
│                          ▲             │      │                                         │
│                          │             │      │                                         │
└─────────────────────────┼─────────────┘      └─────────────────────────────────────────┘
                          │                                       ▲
                          │                                       │
                          │                                       │
                          │       ┌─────────────────┐             │
                          │       │  AWS Transit    │             │
                          └───────┤    Gateway      ├─────────────┘
                                  │                 │
                                  └─────────────────┘
```

## Conclusion

By combining an EC2-based Jenkins controller with ECS-based agents and connecting the VPCs using AWS Transit Gateway, you can create a robust, secure, and scalable CI/CD environment. This architecture provides:

1. **Private Network Communication**: All traffic remains within AWS private network
2. **Scalable Agent Provisioning**: Using ECS for on-demand agent scaling
3. **Customizable Controller Environment**: Full control over the EC2 Jenkins controller
4. **Cross-VPC Connectivity**: Secure connection without VPC peering or public internet

Remember to tune your EC2 instance and JVM parameters to handle the expected load of 1000 concurrent jobs, and consider implementing a high-availability solution for the controller if downtime is a concern.
