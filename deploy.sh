#!/bin/bash
# Deploy Jenkins on AWS ECS for 1000 concurrent jobs

set -e

# Default values
STACK_NAME="jenkins-ecs"
REGION=$(aws configure get region || echo "us-east-1")
VPC_ID=""
PUBLIC_SUBNETS=""
PRIVATE_SUBNETS=""
SSL_CERT_ARN=""
MIN_AGENTS=10
MAX_AGENTS=1000
BATCH_MODE=false
SCHEDULE_SCALE=false
TEST_SCHEDULE=""

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Deploy Jenkins on AWS ECS with high scalability (1000 concurrent jobs)"
    echo ""
    echo "Options:"
    echo "  -h, --help                Show this help message"
    echo "  -n, --stack-name NAME     CloudFormation stack name (default: jenkins-ecs)"
    echo "  -r, --region REGION       AWS region (default: from AWS CLI config)"
    echo "  -v, --vpc-id VPC_ID       VPC ID to deploy into (required)"
    echo "  -u, --public-subnets IDS  Comma-separated list of public subnet IDs (required)"
    echo "  -p, --private-subnets IDS Comma-separated list of private subnet IDs (required)"
    echo "  -c, --certificate-arn ARN ARN of SSL certificate for HTTPS (required)"
    echo "  --min-agents NUMBER       Minimum number of agent instances (default: 10)"
    echo "  --max-agents NUMBER       Maximum number of agent instances (default: 1000)"
    echo "  --batch-mode              Enable batch workload optimizations for periodic testing"
    echo "  --schedule-scale          Enable scheduled scaling (requires --batch-mode)"
    echo "  --test-schedule SCHEDULE  Cron schedule for test runs, e.g. 'cron(0 9 ? * MON-FRI *)'"
    echo ""
    echo "Batch Mode Options:"
    echo "  When --batch-mode is enabled, the deployment is optimized for periodic testing:"
    echo "  - Minimum agents are set to 0 by default"
    echo "  - Spot instance percentage is increased to 90%"
    echo "  - Scheduled scaling can be configured"
    echo ""
    echo "Example:"
    echo "  $0 --vpc-id vpc-12345678 --public-subnets subnet-a,subnet-b --private-subnets subnet-c,subnet-d --certificate-arn arn:aws:acm:... --batch-mode"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -v|--vpc-id)
            VPC_ID="$2"
            shift 2
            ;;
        -u|--public-subnets)
            PUBLIC_SUBNETS="$2"
            shift 2
            ;;
        -p|--private-subnets)
            PRIVATE_SUBNETS="$2"
            shift 2
            ;;
        -c|--certificate-arn)
            SSL_CERT_ARN="$2"
            shift 2
            ;;
        --min-agents)
            MIN_AGENTS="$2"
            shift 2
            ;;
        --max-agents)
            MAX_AGENTS="$2"
            shift 2
            ;;
        --batch-mode)
            BATCH_MODE=true
            # Set default MIN_AGENTS to 0 for batch mode if not explicitly set
            if [ "$MIN_AGENTS" == "10" ]; then
                MIN_AGENTS=0
            fi
            shift
            ;;
        --schedule-scale)
            SCHEDULE_SCALE=true
            shift
            ;;
        --test-schedule)
            TEST_SCHEDULE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check required parameters
if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNETS" ] || [ -z "$PRIVATE_SUBNETS" ] || [ -z "$SSL_CERT_ARN" ]; then
    echo "Error: Missing required parameters"
    show_help
    exit 1
fi

# Validate batch mode options
if [ "$SCHEDULE_SCALE" == "true" ] && [ "$BATCH_MODE" == "false" ]; then
    echo "Error: --schedule-scale requires --batch-mode"
    show_help
    exit 1
fi

if [ "$SCHEDULE_SCALE" == "true" ] && [ -z "$TEST_SCHEDULE" ]; then
    echo "Error: --schedule-scale requires --test-schedule"
    show_help
    exit 1
fi

# Convert comma-separated lists to CloudFormation format
PUBLIC_SUBNETS_CF=$(echo $PUBLIC_SUBNETS | sed 's/,/ /g')
PRIVATE_SUBNETS_CF=$(echo $PRIVATE_SUBNETS | sed 's/,/ /g')

# Set deployment mode specific parameters
SPOT_WEIGHT=3
ON_DEMAND_WEIGHT=1

if [ "$BATCH_MODE" == "true" ]; then
    SPOT_WEIGHT=9
    ON_DEMAND_WEIGHT=1
    echo "Batch mode enabled: Optimizing for periodic testing"
fi

echo "========================================"
echo "Jenkins ECS Deployment"
echo "========================================"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNETS"
echo "Private Subnets: $PRIVATE_SUBNETS"
echo "SSL Certificate ARN: $SSL_CERT_ARN"
echo "Min Agents: $MIN_AGENTS"
echo "Max Agents: $MAX_AGENTS"
echo "Deployment Mode: $([ "$BATCH_MODE" == "true" ] && echo "Batch Optimized" || echo "Standard")"
if [ "$BATCH_MODE" == "true" ]; then
    echo "Spot Instance Ratio: 90% (Spot: $SPOT_WEIGHT, On-Demand: $ON_DEMAND_WEIGHT)"
    if [ "$SCHEDULE_SCALE" == "true" ]; then
        echo "Scheduled Scaling: Enabled"
        echo "Test Schedule: $TEST_SCHEDULE"
    else
        echo "Scheduled Scaling: Disabled"
    fi
fi
echo "========================================"

# Confirm deployment
read -p "Do you want to proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Create AWS Secrets Manager secret for Jenkins agent
echo "Creating Jenkins agent secret in AWS Secrets Manager..."
SECRET_ARN=$(aws secretsmanager create-secret \
    --name JenkinsAgentSecret \
    --description "Secret for Jenkins agents" \
    --secret-string '{"JNLSecretKey":"'$(openssl rand -hex 16)'"}' \
    --region $REGION \
    --output text \
    --query 'ARN')
echo "Secret created: $SECRET_ARN"

# Deploy Jenkins controller
echo "Deploying Jenkins controller..."
CONTROLLER_PARAMS=(
    "VpcId=$VPC_ID"
    "PrivateSubnets=$PRIVATE_SUBNETS_CF"
    "PublicSubnets=$PUBLIC_SUBNETS_CF"
    "SSLCertificateArn=$SSL_CERT_ARN"
)

if [ "$BATCH_MODE" == "true" ]; then
    CONTROLLER_PARAMS+=("BatchModeEnabled=true")
fi

aws cloudformation deploy \
    --stack-name "$STACK_NAME-controller" \
    --template-file jenkins-controller-service.yaml \
    --parameter-overrides "${CONTROLLER_PARAMS[@]}" \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Get outputs from controller stack
echo "Getting controller stack outputs..."
JENKINS_CONTROLLER_SG=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME-controller" \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='JenkinsControllerSecurityGroupId'].OutputValue" \
    --output text)

JENKINS_AGENT_SG=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME-controller" \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='JenkinsAgentSecurityGroupId'].OutputValue" \
    --output text)

JENKINS_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME-controller" \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='JenkinsURL'].OutputValue" \
    --output text)

# Deploy Jenkins agents
echo "Deploying Jenkins agent cluster..."
AGENT_PARAMS=(
    "VpcId=$VPC_ID"
    "PrivateSubnets=$PRIVATE_SUBNETS_CF"
    "JenkinsControllerSecurityGroupId=$JENKINS_CONTROLLER_SG"
    "JenkinsAgentSecurityGroupId=$JENKINS_AGENT_SG"
    "MinAgentCapacity=$MIN_AGENTS"
    "MaxAgentCapacity=$MAX_AGENTS"
    "SpotWeight=$SPOT_WEIGHT"
    "OnDemandWeight=$ON_DEMAND_WEIGHT"
)

if [ "$BATCH_MODE" == "true" ]; then
    AGENT_PARAMS+=("BatchModeEnabled=true")
fi

if [ "$SCHEDULE_SCALE" == "true" ]; then
    AGENT_PARAMS+=(
        "ScheduledScalingEnabled=true"
        "TestSchedule=$TEST_SCHEDULE"
    )
fi

aws cloudformation deploy \
    --stack-name "$STACK_NAME-agents" \
    --template-file jenkins-agent-cluster.yaml \
    --parameter-overrides "${AGENT_PARAMS[@]}" \
    --capabilities CAPABILITY_IAM \
    --region $REGION

echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo "Jenkins URL: $JENKINS_URL"
echo ""
echo "Next steps:"
echo "1. Access Jenkins at the URL above (it may take a few minutes to become available)"
echo "2. Log in with the initial admin password (see below for instructions)"
echo "3. Configure the ECS plugin for dynamic agent provisioning"
echo ""
echo "To retrieve the initial admin password, run:"
echo "aws logs filter-log-events --log-group-name /ecs/jenkins-controller --filter-pattern \"initialAdminPassword\" --region $REGION"
echo ""
if [ "$BATCH_MODE" == "true" ]; then
    echo "Batch mode configuration recommendations:"
    echo "- See COST-OPTIMIZATION-FOR-BATCH-WORKLOADS.md for additional configuration options"
    echo "- Install the 'Prune Workspaces' plugin for efficient storage management"
    echo "- Configure cost allocation tags to track test run expenses"
    echo ""
fi
echo "For detailed configuration instructions, refer to the JENKINS-ECS-DEPLOYMENT-GUIDE.md file"
echo "========================================" 