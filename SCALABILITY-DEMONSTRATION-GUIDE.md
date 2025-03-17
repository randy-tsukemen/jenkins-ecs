# Scalability Demonstration Guide

## Testing the Auto-Scaling Capability of Jenkins on AWS ECS

This guide provides step-by-step instructions for demonstrating and validating the scalability of the Jenkins on AWS ECS architecture. You'll create test jobs, trigger scaling events, and observe how the system scales up and down in response to workload changes.

## Prerequisites

Before starting the demonstration, ensure you have:

1. Successfully deployed the Jenkins on AWS ECS architecture using the deployment script
2. Administrator access to the Jenkins controller
3. AWS CLI configured with appropriate permissions
4. AWS Management Console access

## Preparing the Environment

### 1. Install Required Jenkins Plugins

Log in to Jenkins and install these plugins:

- **Jenkins Job DSL Plugin**: For programmatic job creation
- **Amazon EC2 Container Service Plugin**: For ECS integration
- **Monitoring Plugin**: For visualizing queue metrics
- **Metrics Plugin**: For exposing performance data

### 2. Create Agent Templates

1. Navigate to **Manage Jenkins** > **Cloud** > **Configure Clouds**
2. Verify ECS Cloud configuration is present
3. Configure three agent templates:
   - Small agent (2 vCPU, 4GB RAM)
   - Medium agent (4 vCPU, 8GB RAM)
   - Large agent (8 vCPU, 16GB RAM)
4. Set **Minimum number of instances** to 0 for each template
5. Set **Maximum number of instances** according to your scaling test needs
6. Configure **Idle timeout** to 5 minutes for quick scale-down demonstration

### 3. Set Up CloudWatch Dashboard

Create a custom CloudWatch dashboard to monitor scaling metrics:

```bash
aws cloudwatch create-dashboard --dashboard-name JenkinsScalingDemo --dashboard-body file://scaling-dashboard.json
```

The `scaling-dashboard.json` file should include widgets for:

- ECS service metrics (CPU, memory)
- Auto-scaling group metrics
- Jenkins queue depth
- Number of running ECS tasks
- ECS container instances

## Creating Test Jobs

### 1. Create a Seed Job to Generate Test Jobs

Create a Jenkins job that will generate multiple test jobs using Job DSL:

1. Create a new **Freestyle Project** named "Generate-Test-Jobs"
2. Add a **Process Job DSLs** build step
3. Select "Use the provided DSL script"
4. Enter the following script:

```groovy
// Create 100 test jobs that execute on ECS agents
for (int i = 1; i <= 100; i++) {
    def jobName = "test-job-${i}"

    // Alternate between agent sizes for distribution
    def agentSize = i % 3 == 0 ? "large" : (i % 2 == 0 ? "medium" : "small")

    job(jobName) {
        label("jenkins-agent-${agentSize}")

        steps {
            // Execute a CPU-intensive task (adjustable duration)
            shell('''#!/bin/bash
                # CPU-intensive task: calculate prime numbers
                end=20000
                for ((i=1;i<=end;i++)); do
                    isPrime=1
                    for ((j=2;j*j<=i;j++)); do
                        if [ $((i%j)) -eq 0 ]; then
                            isPrime=0
                            break
                        fi
                    done
                    if [ $isPrime -eq 1 ]; then
                        echo $i >> /dev/null
                    fi
                done

                # Sleep to ensure minimum job duration (adjust as needed)
                echo "Job running for 3 minutes to demonstrate scaling"
                sleep 180
            ''')
        }
    }
}
```

5. Save and run the job to generate the test jobs

### 2. Create a Job Launcher Script

Create a script on the Jenkins controller to trigger jobs in batches:

1. Navigate to **Manage Jenkins** > **Script Console**
2. Execute the following Groovy script to create a launch script:

```groovy
def launchScript = '''#!/bin/bash
# Script to launch multiple Jenkins jobs

# Set variables
JENKINS_URL="http://localhost:8080"
API_TOKEN="${JENKINS_TOKEN}"
USER="admin"
BATCH_SIZE=10
DELAY_SECONDS=15
TOTAL_JOBS=100

# Authenticate using the API token
CURL_AUTH="-u ${USER}:${API_TOKEN}"

# Function to launch a batch of jobs
launch_batch() {
  local start=$1
  local end=$2

  echo "Launching jobs $start to $end..."

  for ((i=start; i<=end; i++)); do
    JOB_NAME="test-job-${i}"
    curl $CURL_AUTH -X POST "${JENKINS_URL}/job/${JOB_NAME}/build"
    echo "Triggered job ${JOB_NAME}"
  done
}

# Launch jobs in batches
for ((i=1; i<=TOTAL_JOBS; i+=$BATCH_SIZE)); do
  end=$((i+BATCH_SIZE-1))
  if [ $end -gt $TOTAL_JOBS ]; then
    end=$TOTAL_JOBS
  fi

  launch_batch $i $end

  # Wait before launching next batch
  echo "Waiting $DELAY_SECONDS seconds before next batch..."
  sleep $DELAY_SECONDS
done

echo "All $TOTAL_JOBS jobs have been scheduled for execution."
'''

// Save the script to a file
def file = new File("/var/jenkins_home/job_launcher.sh")
file.write(launchScript)
file.setExecutable(true)

println "Job launcher script created at: /var/jenkins_home/job_launcher.sh"
println "Update the script with your Jenkins URL and API token before running."
```

3. Note the path of the created script

## Monitoring Tools Setup

### 1. Configure AWS CLI for Monitoring

Create a shell script to monitor ECS scaling:

```bash
#!/bin/bash
# ecs-monitor.sh - Monitor ECS cluster scaling during test

CLUSTER_NAME="jenkins-agent-cluster"
INTERVAL=10  # seconds

echo "Starting ECS cluster monitoring at $(date)"
echo "Press Ctrl+C to stop monitoring"
echo "------------------------------------------------"

while true; do
  timestamp=$(date +"%H:%M:%S")

  # Get running tasks count
  task_count=$(aws ecs describe-clusters \
    --clusters $CLUSTER_NAME \
    --query "clusters[0].runningTasksCount" \
    --output text)

  # Get pending tasks count
  pending_count=$(aws ecs describe-clusters \
    --clusters $CLUSTER_NAME \
    --query "clusters[0].pendingTasksCount" \
    --output text)

  # Get service scaling details
  small_agents=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services jenkins-agent-small \
    --query "services[0].desiredCount" \
    --output text)

  medium_agents=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services jenkins-agent-medium \
    --query "services[0].desiredCount" \
    --output text)

  large_agents=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services jenkins-agent-large \
    --query "services[0].desiredCount" \
    --output text)

  # Print the current status
  echo "[$timestamp] Tasks: $task_count running, $pending_count pending | Agents: $small_agents small, $medium_agents medium, $large_agents large"

  sleep $INTERVAL
done
```

### 2. Set Up Jenkins Metrics Script

Create a script to monitor Jenkins queue and executor status:

```bash
#!/bin/bash
# jenkins-metrics.sh - Monitor Jenkins queue and executor metrics

JENKINS_URL="http://localhost:8080"
API_TOKEN="${JENKINS_TOKEN}"
USER="admin"
INTERVAL=10  # seconds

echo "Starting Jenkins metrics monitoring at $(date)"
echo "Press Ctrl+C to stop monitoring"
echo "------------------------------------------------"

while true; do
  timestamp=$(date +"%H:%M:%S")

  # Get queue info
  queue_length=$(curl -s -u "${USER}:${API_TOKEN}" \
    "${JENKINS_URL}/queue/api/json?tree=items[id]" | \
    jq '.items | length')

  # Get executor info
  executor_info=$(curl -s -u "${USER}:${API_TOKEN}" \
    "${JENKINS_URL}/computer/api/json?tree=computer[displayName,executors[idle]]" | \
    jq '.computer | map({name: .displayName, busy_executors: [.executors[].idle | not] | map(select(. == true)) | length}) | {total_nodes: length, busy_nodes: map(select(.busy_executors > 0)) | length, total_busy_executors: map(.busy_executors) | add}')

  # Extract values from executor info
  total_nodes=$(echo $executor_info | jq '.total_nodes')
  busy_nodes=$(echo $executor_info | jq '.busy_nodes')
  busy_executors=$(echo $executor_info | jq '.total_busy_executors')

  # Print the current status
  echo "[$timestamp] Queue: $queue_length | Nodes: $busy_nodes/$total_nodes | Busy executors: $busy_executors"

  sleep $INTERVAL
done
```

## Running the Scalability Demonstration

### 1. Prepare the Monitoring Environment

1. Open three terminal windows:

   - First terminal: Run the ECS monitoring script
   - Second terminal: Run the Jenkins metrics script
   - Third terminal: For triggering jobs and commands

2. Open the AWS CloudWatch dashboard in your browser

3. Open the Jenkins UI dashboard in another browser tab

### 2. Start with Empty Capacity

1. Ensure no jobs are running:

```bash
# Stop any running jobs
aws ecs update-service --cluster jenkins-agent-cluster \
  --service jenkins-agent-small --desired-count 0

aws ecs update-service --cluster jenkins-agent-cluster \
  --service jenkins-agent-medium --desired-count 0

aws ecs update-service --cluster jenkins-agent-cluster \
  --service jenkins-agent-large --desired-count 0
```

2. Verify all agents are scaled to zero in the monitoring terminal

### 3. Run the Demonstration

#### Scaling Up Test

1. Update the `job_launcher.sh` script with your Jenkins credentials
2. Execute the job launcher script to trigger jobs in batches:

```bash
/var/jenkins_home/job_launcher.sh
```

3. Observe in real-time:

   - The Jenkins queue filling with jobs
   - ECS services scaling up to handle the load
   - New agent nodes appearing in Jenkins
   - Jobs being distributed to the new agents

4. Record the following metrics:
   - Time until first ECS tasks start (typically 30-60 seconds)
   - Rate of scaling (e.g., tasks per minute)
   - Maximum number of concurrent agents
   - Queue behavior during scaling
   - Job distribution across agent sizes

#### Scaling Down Test

1. After all jobs complete, observe:

   - Agents becoming idle
   - ECS services scaling down after idle timeout
   - Return to zero or baseline capacity

2. Record the following metrics:
   - Time until tasks start terminating
   - Rate of scale-down
   - Any throttling or limitations observed

## Analyzing Results

### Success Criteria

The demonstration is successful if:

1. The system automatically scales up to handle all 100 jobs within a reasonable timeframe (typically 5-10 minutes)
2. Jobs are distributed appropriately across agent sizes
3. The system scales back down when jobs complete
4. No manual intervention was required

### Key Metrics to Report

Document the following metrics from your demonstration:

1. **Scale-Up Performance**:

   - Time to first agent: \_\_\_ seconds
   - Time to reach 50% capacity: \_\_\_ minutes
   - Time to reach full capacity: \_\_\_ minutes
   - Maximum agents provisioned: \_\_\_
   - Maximum concurrent jobs: \_\_\_

2. **Job Execution**:

   - Average job wait time: \_\_\_ seconds
   - Average job execution time: \_\_\_ minutes
   - Job distribution: **_% small, _**% medium, \_\_\_% large agents

3. **Scale-Down Performance**:

   - Time from job completion to agent termination: \_\_\_ minutes
   - Scale-down rate: \_\_\_ agents per minute

4. **Resource Utilization**:
   - Peak CPU utilization: \_\_\_%
   - Peak memory utilization: \_\_\_%
   - Controller stability during peak: Stable/Unstable

## Extrapolating to 1000 Jobs

Based on the results of the 100-job test, you can extrapolate to 1000 jobs:

1. **Scaling Capacity**: If 100 jobs resulted in X agents, 1000 jobs would require approximately 10X agents, which is within AWS ECS capacity limits (5000 tasks per cluster)

2. **Scaling Time**: Scale-up time may increase due to AWS API rate limiting. For 1000 jobs, expect approximately 3-5x longer scaling time (not 10x due to parallel provisioning)

3. **Controller Load**: For 1000 jobs, controller optimization becomes critical. Monitor controller CPU/memory during the test to project resource needs for 1000 jobs

4. **Network and API Limits**: For 1000 jobs, AWS API throttling may become a factor. Consider implementing exponential backoff in job submission for the full-scale test

## Further Testing Recommendations

To validate the full 1000-job capacity:

1. **Incremental Testing**: Perform tests with increasing job counts: 100, 250, 500, then 1000

2. **Realistic Workloads**: Replace the sample CPU-intensive script with realistic job workloads that match your actual use case

3. **Extended Monitoring**: For larger tests, extend monitoring to include:

   - AWS API throttling metrics
   - EFS throughput and IOPS
   - Network flows and bottlenecks

4. **Controller Scaling**: For 1000-job tests, consider temporarily scaling up the controller resources (8 vCPU, 32GB+)

## Conclusion

This demonstration validates that the Jenkins on AWS ECS architecture can effectively scale to handle large batches of concurrent jobs. By successfully scaling to handle 100 concurrent jobs, the architecture demonstrates the core auto-scaling mechanisms that enable scaling to the full 1000-job capacity.

The elasticity of the ECS-based agent architecture ensures optimal resource usage, with capacity growing and shrinking based on actual demand, making it ideal for the periodic testing use case described in the cost optimization document.
