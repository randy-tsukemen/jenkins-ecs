#!/bin/bash
set -e

# Add Jenkins agent setup if needed
if [ -n "$JENKINS_URL" ] && [ -n "$JENKINS_SECRET" ] && [ -n "$JENKINS_AGENT_NAME" ]; then
  # Connect to Jenkins master
  exec java -jar /usr/share/jenkins/agent.jar \
    -jnlpUrl "${JENKINS_URL}/computer/${JENKINS_AGENT_NAME}/slave-agent.jnlp" \
    -secret "${JENKINS_SECRET}" \
    -workDir "/home/jenkins"
else
  # If not run as Jenkins agent, just run the command
  exec "$@"
fi 