# 🔭 Week 4 – Jenkins Observability Challenge

**Theme:** Observability, Metrics, Logs, Traces & Dashboards

> **Goal:** Complete observability for Jenkins CI/CD system - "Know Your CI Pipeline in One Glance"

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
- [Testing the Setup](#testing-the-setup)
- [Failure Drill](#failure-drill)
- [Battle Log](#battle-log)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This challenge implements a complete observability stack for Jenkins CI/CD, including:

- **Metrics:** Prometheus scraping Jenkins metrics
- **Dashboards:** Grafana visualizations for CI/CD insights
- **Tracing:** OpenTelemetry integration with Jaeger
- **Alerting:** Prometheus alerts with detailed runbooks
- **Failure Simulation:** Automated failure drill pipeline

### What You'll Learn

- Setting up Prometheus metrics collection
- Creating meaningful Grafana dashboards
- Implementing distributed tracing with OpenTelemetry
- Configuring alerts and writing runbooks
- Debugging CI/CD issues using observability data

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                  │
│  ┌──────────────────────┐      ┌─────────────────────────────┐ │
│  │   Jenkins VM         │      │   Monitoring VM              │ │
│  │                      │      │                              │ │
│  │  • Jenkins           │─────▶│  • Prometheus                │ │
│  │  • Prometheus Plugin │      │  • Grafana                   │ │
│  │  • OpenTelemetry     │─────▶│  • Jaeger                    │ │
│  │    Plugin            │      │  • OTel Collector            │ │
│  │                      │      │                              │ │
│  │  :8080 (Jenkins)     │      │  :9090 (Prometheus)          │ │
│  │  :8080/prometheus    │      │  :3000 (Grafana)             │ │
│  │                      │      │  :16686 (Jaeger)             │ │
│  └──────────────────────┘      └─────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

         Metrics Flow: Jenkins → Prometheus → Grafana
         Traces Flow:  Jenkins → OTel Collector → Jaeger
         Alerts Flow:  Prometheus → AlertManager (optional)
```

### Components

| Component | Purpose | Port |
|-----------|---------|------|
| **Jenkins** | CI/CD server | 8080 |
| **Prometheus** | Metrics collection | 9090 |
| **Grafana** | Visualization | 3000 |
| **Jaeger** | Distributed tracing | 16686 |
| **OTel Collector** | Trace aggregation | 4317, 4318 |

---

## 📦 Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **AWS CLI** (configured with credentials)
- **jq** (for JSON processing)
- **SSH client**
- **Git**

### AWS Requirements

- AWS account with EC2 permissions
- Available quota for:
  - 2x EC2 instances (t3.medium + t3.large)
  - 1x VPC
  - 2x Security Groups
  - Elastic IPs (optional)

### Installation

```bash
# macOS
brew install terraform awscli jq

# Ubuntu/Debian
sudo apt-get install terraform awscli jq

# Configure AWS
aws configure
```

---

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Clone or navigate to the project
cd observability-challenge

# Make scripts executable
chmod +x scripts/*.sh

# Deploy everything
./scripts/deploy.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Create SSH key pair
3. ✅ Deploy infrastructure (Terraform)
4. ✅ Wait for instances to be ready
5. ✅ Configure Prometheus
6. ✅ Configure OpenTelemetry Collector
7. ✅ Import Grafana dashboard
8. ✅ Display access information

**Duration:** ~10-15 minutes

### Option 2: Manual Deployment

See [Step-by-Step Guide](#step-by-step-guide) below.

---

## 📖 Step-by-Step Guide

### Step 1: Infrastructure Setup

```bash
cd infrastructure

# Update terraform.tfvars with your settings
vim terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply

# Save outputs
terraform output > ../deployment-info.txt
```

### Step 2: Configure Prometheus

```bash
# Get IPs
JENKINS_IP=$(terraform output -raw jenkins_private_ip)
MONITORING_IP=$(terraform output -raw monitoring_public_ip)

# Update Prometheus config with Jenkins IP
sed -i "s/JENKINS_PRIVATE_IP/$JENKINS_IP/g" ../configs/prometheus/prometheus.yml

# Copy configs to monitoring server
scp -i ~/.ssh/your-key.pem \
    ../configs/prometheus/prometheus.yml \
    ../configs/prometheus/alert_rules.yml \
    ubuntu@$MONITORING_IP:/tmp/

# SSH to monitoring server
ssh -i ~/.ssh/your-key.pem ubuntu@$MONITORING_IP

# Move configs and restart
sudo mv /tmp/prometheus.yml /etc/prometheus/
sudo mv /tmp/alert_rules.yml /etc/prometheus/
sudo chown prometheus:prometheus /etc/prometheus/*.yml
sudo systemctl restart prometheus
```

### Step 3: Configure Jenkins

1. **Access Jenkins:** `http://JENKINS_IP:8080`

2. **Get initial password:**
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@JENKINS_IP
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

3. **Complete setup wizard:**
   - Install suggested plugins
   - Create admin user
   - Configure Jenkins URL

4. **Verify Prometheus plugin:**
   - Manage Jenkins → Manage Plugins
   - Check "Installed" tab for "Prometheus metrics plugin"
   - Visit: `http://JENKINS_IP:8080/prometheus`

### Step 4: Configure OpenTelemetry

1. **Install OpenTelemetry plugin:**
   - Manage Jenkins → Manage Plugins → Available
   - Search "OpenTelemetry"
   - Install without restart

2. **Configure plugin:**
   - Manage Jenkins → Configure System
   - Find "OpenTelemetry" section
   - Set endpoint: `http://MONITORING_PRIVATE_IP:4317`
   - Enable traces, metrics, logs
   - Service name: `jenkins-ci`

See detailed instructions in: `configs/jenkins/jenkins-otel-config.md`

### Step 5: Import Grafana Dashboard

```bash
# Access Grafana
open http://MONITORING_IP:3000
# Login: admin / admin

# Add Prometheus datasource
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }' \
  "http://MONITORING_IP:3000/api/datasources"

# Import dashboard
# UI: Dashboards → Import → Upload JSON
# File: configs/grafana/jenkins-dashboard.json
```

### Step 6: Create Jenkins Pipelines

1. **Sample Pipeline:**
   - New Item → Pipeline
   - Copy from: `pipelines/sample-pipeline.groovy`

2. **Failure Drill Pipeline:**
   - New Item → Pipeline
   - Copy from: `pipelines/failure-drill-pipeline.groovy`

3. **Load Test Pipeline:**
   - Copy from: `pipelines/load-test-pipeline.groovy`

4. **Queue Test Pipeline:**
   - Copy from: `pipelines/queue-test-pipeline.groovy`

---

## 🧪 Testing the Setup

### Verify Installation

```bash
./scripts/verify-setup.sh
```

This checks:
- ✅ Jenkins is accessible
- ✅ Prometheus is scraping Jenkins
- ✅ Grafana has datasource
- ✅ Dashboard is imported
- ✅ Jaeger is running
- ✅ Alerts are configured

### Test Metrics Collection

1. **Run sample pipeline** (2-3 times)
2. **Check Prometheus:**
   - `http://MONITORING_IP:9090`
   - Query: `jenkins_job_builds_total`
   - Should see metrics

3. **Check Grafana:**
   - Dashboard should show builds
   - Panels should have data (not "No Data")

### Test Tracing

1. **Run sample pipeline**
2. **Check Jaeger:**
   - `http://MONITORING_IP:16686`
   - Service: `jenkins-ci`
   - Should see trace for the build

---

## 💥 Failure Drill

### Running the Drill

1. **Open Jenkins**
2. **Navigate to** "Failure Drill Pipeline"
3. **Build with Parameters:**
   - Failure Type: `EXIT_CODE`
   - Failure Stage: `BUILD`
   - Delay: `10` seconds

4. **Click "Build"**

### What to Observe

| System | What to Check | Expected Result |
|--------|---------------|-----------------|
| **Prometheus** | Query: `jenkins_job_builds_failure_total` | Counter increases |
| **Grafana** | "Failed Builds (5m)" panel | Shows +1 |
| **Alerts** | Prometheus → Alerts | "JenkinsBuildFailureSpike" fires |
| **Jaeger** | Search for build trace | Shows failed span |
| **Logs** | Jenkins console output | Error message visible |

### Drill Scenarios

Run each scenario and observe:

1. **Exit Code Failure:**
   - Type: `EXIT_CODE`
   - Alert: Build Failure Spike ✅

2. **Slow Build:**
   - Type: `TIMEOUT`
   - Alert: Slow Build ✅

3. **Test Failure:**
   - Type: `TEST_FAILURE`
   - Stage: `TEST`

4. **Flaky Test:**
   - Type: `FLAKY`
   - May pass or fail randomly

### Load Testing

**Executor Saturation Test:**

```bash
# Trigger queue-test-pipeline 10 times
for i in {1..10}; do
  # Use Jenkins CLI or UI to trigger builds
  echo "Triggering build $i"
done

# Expected:
# - jenkins_queue_size > 5
# - "JenkinsQueueBacklog" alert fires
# - Executor saturation increases
```

---

## 📝 Battle Log

After running the failure drill, complete the battle log:

**File:** `docs/BATTLE_LOG.md`

### Required Sections

1. **Which metric caught the issue first?**
   - Document the first indicator
   - Include Prometheus query
   - Screenshot

2. **Did the alert fire?**
   - Alert name
   - Time to fire
   - Screenshot from Prometheus

3. **Were dashboards helpful?**
   - Which panels were useful?
   - What information did they provide?
   - Screenshots

4. **Root cause from logs?**
   - Console output analysis
   - Error messages
   - Stack traces

5. **Trace view matched?**
   - Jaeger screenshot
   - Span hierarchy
   - Failed span details

6. **What would you trust in a real incident?**
   - Rank: Metrics, Logs, Traces, Dashboards
   - Reasoning
   - Recommendations

See template: `docs/BATTLE_LOG_TEMPLATE.md`

---

## 🔧 Troubleshooting

### Jenkins Issues

**Problem:** Jenkins not accessible

```bash
# Check Jenkins status
ssh ubuntu@JENKINS_IP
sudo systemctl status jenkins

# Check logs
sudo journalctl -u jenkins -f

# Restart Jenkins
sudo systemctl restart jenkins
```

**Problem:** Prometheus metrics not available

```bash
# Check plugin installation
# Jenkins → Manage Plugins → Installed → Search "Prometheus"

# Check metrics endpoint
curl http://JENKINS_IP:8080/prometheus

# Should see: jenkins_* metrics
```

### Prometheus Issues

**Problem:** Jenkins target down

```bash
# Check Prometheus targets
open http://MONITORING_IP:9090/targets

# Verify network connectivity
ssh ubuntu@MONITORING_IP
telnet JENKINS_PRIVATE_IP 8080

# Check Prometheus config
sudo cat /etc/prometheus/prometheus.yml

# Restart Prometheus
sudo systemctl restart prometheus
```

### Grafana Issues

**Problem:** Dashboard shows "No Data"

1. **Check datasource:**
   - Settings → Data Sources → Prometheus
   - Click "Test" → Should be green

2. **Check queries:**
   - Dashboard → Panel → Edit
   - Query inspector
   - Verify metrics exist in Prometheus

3. **Check time range:**
   - Dashboard time picker (top right)
   - Ensure it covers recent builds

### OpenTelemetry Issues

**Problem:** No traces in Jaeger

```bash
# Check OTel Collector
ssh ubuntu@MONITORING_IP
sudo systemctl status otelcol
sudo journalctl -u otelcol -f

# Check Jaeger
sudo systemctl status jaeger

# Check Jenkins OTel config
# Jenkins → Manage Jenkins → Configure System → OpenTelemetry
# Verify endpoint is correct
```

**Problem:** Partial traces

- Check sampling ratio (should be 1.0 for 100%)
- Check ignored steps configuration
- Review OTel collector logs

---

## 📚 Additional Resources

### Documentation

- [Jenkins Prometheus Plugin](https://plugins.jenkins.io/prometheus/)
- [Jenkins OpenTelemetry Plugin](https://plugins.jenkins.io/opentelemetry/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

### Project Files

- **Runbooks:** `configs/prometheus/RUNBOOKS.md`
- **OTel Config:** `configs/jenkins/jenkins-otel-config.md`
- **Pipelines:** `pipelines/`
- **Scripts:** `scripts/`

### Useful Prometheus Queries

```promql
# Total builds
sum(jenkins_job_builds_total)

# Success rate
sum(rate(jenkins_job_builds_success_total[5m])) / sum(rate(jenkins_job_builds_total[5m]))

# Failure rate
rate(jenkins_job_builds_failure_total[5m])

# Average build duration
avg(jenkins_job_last_build_duration_seconds)

# Executor utilization
(jenkins_executor_busy / jenkins_executor_count) * 100

# Queue depth
jenkins_queue_size
```

---

## 🧹 Cleanup

When you're done with the challenge:

```bash
./scripts/cleanup.sh
```

This will:
- Destroy all AWS resources
- Delete SSH key pair
- Clean up Terraform state
- Remove deployment files

**Warning:** This is irreversible!

---

## 🎓 Challenge Completion Checklist

- [ ] Infrastructure deployed successfully
- [ ] Jenkins accessible and configured
- [ ] Prometheus scraping Jenkins metrics
- [ ] Grafana dashboard showing data
- [ ] OpenTelemetry traces in Jaeger
- [ ] All 4 alerts configured
- [ ] Runbooks reviewed
- [ ] Sample pipeline runs successfully
- [ ] Failure drill executed
- [ ] All observability systems verified during drill
- [ ] Battle log completed
- [ ] Screenshots collected
- [ ] Lessons learned documented

---

## 📄 License

This project is for educational purposes.

---

## 🤝 Contributing

Found an issue or have suggestions? Please document them in your battle log!

---

**Good luck with the challenge! 🚀**

*Remember: In production, observability isn't optional—it's essential!*

