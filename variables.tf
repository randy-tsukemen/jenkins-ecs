variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # Change to your region
}

variable "vpc_id" {
  description = "ID of the VPC-A"
  type        = string
  default     = "vpc-a-id"  # Replace with actual VPC ID
}

variable "subnet_ids" {
  description = "List of subnet IDs in VPC-A"
  type        = list(string)
  default     = ["subnet-id1", "subnet-id2"]  # Replace with actual subnet IDs
}

variable "jenkins_master_sg_id" {
  description = "Security group ID for Jenkins master"
  type        = string
  default     = "sg-jenkins-master-id"  # Replace with actual SG ID
}

variable "vpc_cidr" {
  description = "CIDR block for VPC-A"
  type        = string
  default     = "10.0.0.0/16"  # Replace with actual CIDR
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "jenkins-agent-cluster"
}

variable "min_capacity" {
  description = "Minimum capacity for ECS service"
  type        = number
  default     = 5
}

variable "max_capacity" {
  description = "Maximum capacity for ECS service"
  type        = number
  default     = 100
}

variable "jenkins_agent_image_name" {
  description = "Name of the Jenkins agent ECR repository"
  type        = string
  default     = "jenkins-agent"
}

variable "ecs_ami_id" {
  description = "ID of the Amazon ECS-optimized AMI to use for the container instances"
  type        = string
  default     = "ami-0fe5f366c083f59ca"  # Amazon ECS-optimized AMI for us-east-1; update for your region
} 