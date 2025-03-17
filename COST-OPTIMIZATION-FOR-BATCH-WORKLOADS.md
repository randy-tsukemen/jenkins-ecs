# Cost Optimization for Batch Workloads

## Optimizing Jenkins on AWS ECS for Periodic High-Scale Testing

This document addresses the specific scenario of running large-scale tests (1000 concurrent jobs) approximately 10 times per week, with minimal Jenkins usage during other periods.

## Suitability Analysis

The Jenkins on AWS ECS architecture is particularly well-suited for this periodic batch workload pattern for the following reasons:

### Advantages for Periodic Testing

1. **Elastic Auto-Scaling**: The architecture dynamically scales up only when needed for test runs
2. **Scale-to-Zero Capability**: During idle periods, agent count can be reduced to zero
3. **Cost-Effective Resource Utilization**: Pay only for the compute resources used during test windows
4. **Consistent Performance**: Each test run gets consistent performance regardless of previous activity
5. **Scheduled Capacity**: Pre-warming can be scheduled to align with planned test execution windows

### Architecture Adjustments for Batch Workloads

For workloads with distinct active/idle periods, we recommend the following adjustments to the standard high-scale architecture:

1. **Schedule-Based Scaling**:

   - Pre-defined scaling schedules aligned with test windows
   - Automated scale-up before test execution
   - Aggressive scale-down after tests complete

2. **Controller Sizing**:

   - Controller can be downsized during idle periods (2 vCPU/8GB)
   - Scale controller up before test runs (4 vCPU/16GB)

3. **EFS Optimizations**:

   - Use EFS Infrequent Access storage class
   - Implement aggressive workspace cleanup

4. **Reserved Capacity Strategy**:
   - Reserved Instances for controller (1-year commitment)
   - Spot Instances for 90% of agents (up from standard 70%)
   - Small pool of on-demand instances for quick starting capacity

## Cost Estimate

The following cost estimate is based on AWS pricing in the US East (N. Virginia) region as of 2023, for a workload with:

- 10 large-scale test runs per week (1000 concurrent jobs)
- 15-minute average duration per test run (2.5 hours/week, ~10 hours/month)
- Minimal usage during non-test periods

> **Note on Test Run Duration**: This calculation assumes that each test run completes in 15 minutes with all 1000 jobs running concurrently. The total monthly active hours for agents is calculated as:  
> 10 test runs/week × 4 weeks/month × 15 minutes/run = 600 minutes = 10 hours
>
> This represents a 93.75% reduction from the previous 4-hour test duration scenario.

### Monthly Cost Breakdown

| Component                    | Configuration  | Active Hours | Idle Hours | Monthly Cost |
| ---------------------------- | -------------- | ------------ | ---------- | ------------ |
| **Jenkins Controller**       |                |              |            |              |
| Fargate (Reserved)           | 4 vCPU, 16GB   | 10           | 694        | $105         |
| **Storage**                  |                |              |            |              |
| EFS Standard                 | 50GB           | -            | -          | $15          |
| EFS-IA                       | 100GB          | -            | -          | $12.50       |
| **Agent Compute**            |                |              |            |              |
| Small Agents (2 vCPU, 4GB)   | 500 peak       | 10           | 0          | $60          |
| Medium Agents (4 vCPU, 8GB)  | 330 peak       | 10           | 0          | $79.20       |
| Large Agents (8 vCPU, 16GB)  | 170 peak       | 10           | 0          | $81.60       |
| Standby Agents (2 vCPU, 4GB) | 2 instances    | 0            | 694        | $65          |
| **Network**                  |                |              |            |              |
| Application Load Balancer    | 1 ALB          | 704          | -          | $18          |
| Data Transfer                | 100GB          | -            | -          | $9           |
| **Monitoring**               |                |              |            |              |
| CloudWatch                   | Metrics & Logs | -            | -          | $25          |
| **Other AWS Services**       |                |              |            |              |
| Secrets Manager, ECR         | -              | -            | -          | $15          |
| **Total**                    |                |              |            | **$485.30**  |

> Note: The controller cost remains relatively unchanged as it runs continuously, while agent costs are dramatically reduced due to the shorter test duration.

### Cost Comparison: 15-Minute vs. 4-Hour Test Runs

| Cost Component       | 4-Hour Test Runs | 15-Minute Test Runs | Savings |
| -------------------- | ---------------- | ------------------- | ------- |
| Agent Compute        | $3,533           | $221                | 93.75%  |
| Fixed Infrastructure | $300.50          | $264.30             | 12%     |
| Total Monthly        | $3,833.50        | $485.30             | 87.34%  |

The dramatic reduction in agent compute costs demonstrates how the architecture's elasticity provides significant cost advantages for shorter test durations.

### Cost Optimization Strategies

With the following optimizations specifically for this very short-duration batch workload pattern, the monthly cost can be further reduced:

1. **Scheduled Scaling**:

   - Turn off all standby agents during non-business hours: -$32
   - Schedule controller to lower capacity during idle periods: -$30

2. **Spot Instance Strategy**:

   - Increase Spot usage to 95% of agent fleet: -$11
   - Implement graceful interruption handling

3. **Storage Optimizations**:

   - Aggressive workspace cleanup policies: -$10
   - Move older build artifacts to S3 Glacier: -$8

4. **Compute Optimizations**:

   - Use Graviton2-based instances where possible: -$20
   - Fine-tune agent resource allocation based on usage patterns: -$15

5. **Provisioning Optimizations**:

   - Implement warm pool for faster scaling: +$15 (small cost increase)
   - Optimize pre-warming timing for minimal idle time: -$10

### Optimized Monthly Cost Estimate: **$374.30**

### Key Cost Insights for 15-Minute Test Runs

1. **Agent Costs Are Minimal**: With only 10 hours of active time per month, the agent compute cost is already very low (~$221 total)
2. **Fixed Costs Dominate**: Infrastructure components like the controller, storage, and ALB become the main cost drivers
3. **Optimization Focus Shifts**: Cost optimization should focus on reducing fixed infrastructure costs rather than agent compute
4. **Startup Performance Is Critical**: With short test runs, ensuring rapid agent provisioning becomes more important than long-term cost efficiency

## Implementation Recommendations for Short-Duration Tests

To implement this cost-optimized solution for short batch workloads:

1. **Pre-warming Strategy**:

   - Schedule pre-warming 5-10 minutes before test runs
   - Maintain a small warm pool of agents to avoid cold start delays

2. **Jenkins Configuration**:

   - Configure parallel job execution to maximize utilization during short runs
   - Set aggressive timeouts to prevent runaway jobs (e.g., 30-minute maximum)
   - Install the "Prune Workspaces" plugin for automated cleanup

3. **Monitoring Enhancements**:

   - Create detailed metrics for agent startup time and test completion
   - Track agent utilization to identify optimization opportunities
   - Set up budget alerts for cost spikes

## Conclusion

The proposed Jenkins on AWS ECS architecture is extraordinarily cost-effective for short-duration periodic testing. With 15-minute test runs, the monthly compute cost for agents drops dramatically (from $3,533 to $221), making this an extremely economical solution for high-scale periodic testing.

This architecture offers the perfect balance of massive on-demand capacity (1000 concurrent jobs) with minimal ongoing costs, resulting in an optimized monthly expense of approximately $374.30.
