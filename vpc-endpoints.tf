# VPC Endpoints for AWS services to work without internet access

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.vpc_a.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  
  tags = {
    Name = "s3-vpc-endpoint"
  }
}

# ECR API Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

# ECR DKR Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}

# CloudWatch Logs Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "logs-vpc-endpoint"
  }
}

# ECS Endpoint
resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.ecs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecs-vpc-endpoint"
  }
}

# ECS Agent Endpoint
resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = ["subnet-id1", "subnet-id2"] # Replace with actual subnet IDs
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecs-agent-vpc-endpoint"
  }
}

# ECS Telemetry Endpoint
resource "aws_vpc_endpoint" "ecs_telemetry" {
  vpc_id              = data.aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.region}.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = ["subnet-id1", "subnet-id2"] # Replace with actual subnet IDs
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecs-telemetry-vpc-endpoint"
  }
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.vpc_a.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.vpc_a.id

  tags = {
    Name = "jenkins-ecs-private-route-table"
  }
}

# Route table associations for private subnets
resource "aws_route_table_association" "private" {
  count          = length(var.subnet_ids)
  subnet_id      = var.subnet_ids[count.index]
  route_table_id = aws_route_table.private.id
} 