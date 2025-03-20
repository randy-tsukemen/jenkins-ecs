FROM jenkins/inbound-agent:latest

USER root

# Install necessary tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    zip \
    sudo \
    openssh-server \
    xvfb \
    awscli \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Install packages needed for the build process
RUN pip3 install --no-cache-dir \
    catkin_pkg \
    rospkg \
    rosdep

# Create directory structure expected by the build
RUN mkdir -p /abe_tmp/CICT_ScenarioTest/projects
RUN mkdir -p /home/jenkins/judgtools/Out
RUN mkdir -p /home/jenkins/judgtools/tool/Source

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch back to jenkins user
USER jenkins

ENTRYPOINT ["/entrypoint.sh"] 