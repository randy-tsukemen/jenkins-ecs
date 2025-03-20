provider "aws" {
  region = var.region
}

# VPC and networking - use existing VPC-A
data "aws_vpc" "vpc_a" {
  id = var.vpc_id
}

# ECS Cluster
resource "aws_ecs_cluster" "jenkins_agent_cluster" {
  name = var.ecs_cluster_name
}

# EC2 Launch Template for ECS instances
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "jenkins-agent-"
  image_id      = var.ecs_ami_id # Amazon ECS-optimized AMI ID
  instance_type = "c5.large"     # Choose an appropriate instance size

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 100
      volume_type = "gp3"
    }
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_instances.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.jenkins_agent_cluster.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    echo ECS_CONTAINER_INSTANCE_TAGS={\"Name\":\"jenkins-agent-instance\"} >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "jenkins-agent-instance"
    }
  }
}

# Auto Scaling Group for ECS instances
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "jenkins-agent-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = 2
  max_size            = 10
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "jenkins_agents" {
  name = "jenkins-agent-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }
}

# Associate capacity provider with cluster
resource "aws_ecs_cluster_capacity_providers" "jenkins_cluster_cp" {
  cluster_name       = aws_ecs_cluster.jenkins_agent_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.jenkins_agents.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.jenkins_agents.name
    weight            = 100
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "jenkins_agent" {
  family                   = "jenkins-agent"
  network_mode             = "bridge" # Changed from awsvpc to bridge
  requires_compatibilities = ["EC2"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "jenkins-agent"
      image     = "${aws_ecr_repository.jenkins_agent.repository_url}:latest"
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/jenkins-agent"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          containerPort = 22
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]
      mountPoints = []
      volumesFrom = []
    }
  ])
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "jenkins-agent-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "jenkins-agent-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role for EC2 instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "jenkins-agent-ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "jenkins-agent-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Private ECR Repository
resource "aws_ecr_repository" "jenkins_agent" {
  name = var.jenkins_agent_image_name
}

# Security Group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "jenkins-agent-ecs-sg"
  description = "Security group for Jenkins ECS instances"
  vpc_id      = data.aws_vpc.vpc_a.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc_a.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.vpc_a.cidr_block]
  }
}

# CloudWatch Logs Group
resource "aws_cloudwatch_log_group" "jenkins_agent" {
  name              = "/ecs/jenkins-agent"
  retention_in_days = 14
} 