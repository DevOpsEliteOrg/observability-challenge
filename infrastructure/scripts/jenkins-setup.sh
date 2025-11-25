#!/bin/bash
set -e

# Jenkins Installation and Configuration Script
# This script installs Jenkins with Prometheus Metrics Plugin and OpenTelemetry Plugin

echo "==================================="
echo "Jenkins Setup Script Starting"
echo "==================================="

# Update system
apt-get update
apt-get upgrade -y

# Install Java
apt-get install -y fontconfig openjdk-17-jre

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
apt-get update
apt-get install -y jenkins

# Start Jenkins
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 30

# Get Jenkins initial admin password
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

# Install Jenkins CLI
wget -O /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar

# Wait for Jenkins to be fully ready
until curl -s http://localhost:8080 | grep -q "Jenkins"; do
  echo "Waiting for Jenkins to be ready..."
  sleep 5
done

# Install required plugins using Jenkins CLI
echo "Installing Jenkins plugins..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:${JENKINS_PASSWORD} install-plugin \
  prometheus \
  opentelemetry \
  pipeline-stage-view \
  git \
  workflow-aggregator \
  -restart

# Wait for Jenkins to restart
sleep 60

# Create Jenkins config for Prometheus metrics
mkdir -p /var/lib/jenkins/prometheus
cat > /var/lib/jenkins/prometheus/prometheus.yml <<'EOF'
# Prometheus metrics will be available at http://jenkins:8080/prometheus
EOF

# Set ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Print initial password
echo "==================================="
echo "Jenkins Installation Complete!"
echo "==================================="
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Initial Admin Password: ${JENKINS_PASSWORD}"
echo ""
echo "Prometheus metrics endpoint: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/prometheus"
echo "==================================="

# Save credentials to file
cat > /tmp/jenkins-credentials.txt <<EOF
Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080
Username: admin
Password: ${JENKINS_PASSWORD}
EOF

echo "Credentials saved to /tmp/jenkins-credentials.txt"

