# 🚀 Quick Start Guide - Jenkins Observability Challenge

**Time Required:** 15-20 minutes  
**Difficulty:** Intermediate

---

## Prerequisites Check

```bash
# Check required tools
command -v terraform >/dev/null 2>&1 || echo "❌ Install Terraform"
command -v aws >/dev/null 2>&1 || echo "❌ Install AWS CLI"
command -v jq >/dev/null 2>&1 || echo "❌ Install jq"

# Verify AWS credentials
aws sts get-caller-identity
```

---

## 5-Minute Deployment

### Step 1: Clone/Navigate to Project

```bash
cd observability-challenge
```

### Step 2: Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### Step 3: Deploy Everything

```bash
./scripts/deploy.sh
```

**What it does:**
- Creates EC2 instances (Jenkins + Monitoring)
- Installs all required software
- Configures Prometheus, Grafana, Jaeger
- Sets up dashboards and alerts

**Grab a coffee ☕ - this takes ~10 minutes**

### Step 4: Save Your Info

After deployment completes, save the output:

```bash
# URLs will be displayed
# Copy these to a safe place:
# - Jenkins URL and password
# - Prometheus URL
# - Grafana URL
# - Jaeger URL
# - SSH commands
```

---

## First 5 Minutes After Deployment

### 1. Access Jenkins (1 min)

```bash
# Open Jenkins (URL from deployment output)
open http://JENKINS_IP:8080

# Login with:
# Username: admin
# Password: [from deployment output]
```

### 2. Verify Prometheus Metrics (1 min)

```bash
# Open Prometheus
open http://MONITORING_IP:9090

# Run this query:
up{job="jenkins"}

# Should return: 1 (Jenkins is up)
```

### 3. Check Grafana Dashboard (1 min)

```bash
# Open Grafana
open http://MONITORING_IP:3000

# Login: admin / admin
# Go to: Dashboards → Jenkins CI/CD Overview
```

### 4. Verify Setup (2 min)

```bash
./scripts/verify-setup.sh

# Should show all green ✅
```

---

## Create Your First Pipeline (5 min)

### Option 1: Using Jenkins UI

1. **New Item** → Name: "Sample Pipeline" → **Pipeline**
2. **Pipeline Script:**
   - Copy entire content from: `pipelines/sample-pipeline.groovy`
3. **Save** → **Build Now**

### Option 2: Using Jenkins CLI

```bash
# (From deployment output, get Jenkins CLI command)
# Create pipeline via CLI or UI
```

### Watch the Magic ✨

After building:

1. **Prometheus**: Query `jenkins_job_builds_total`
2. **Grafana**: See builds in dashboard
3. **Jaeger**: Search service `jenkins-ci`
4. **Jenkins**: Check console output

---

## Run the Failure Drill (5 min)

### Create Failure Drill Pipeline

1. **Jenkins** → **New Item** → "Failure Drill"
2. **Copy from:** `pipelines/failure-drill-pipeline.groovy`
3. **Save**

### Execute Drill

1. **Build with Parameters**
2. **Select:**
   - Failure Type: `EXIT_CODE`
   - Failure Stage: `BUILD`
   - Delay: `10` seconds
3. **Build**

### Observe Everything

**Open these tabs side-by-side:**

1. Jenkins console output
2. Prometheus (query: `jenkins_job_builds_failure_total`)
3. Grafana dashboard
4. Prometheus alerts page
5. Jaeger trace view

**Expected Results:**

- ✅ Build fails after 10 seconds
- ✅ Failure counter increases
- ✅ Dashboard shows failed build
- ✅ Alert fires: "JenkinsBuildFailureSpike"
- ✅ Trace shows failed span

---

## Quick Reference Card

### Important URLs

```bash
Jenkins:     http://JENKINS_IP:8080
Prometheus:  http://MONITORING_IP:9090
Grafana:     http://MONITORING_IP:3000
Jaeger:      http://MONITORING_IP:16686
```

### Useful Prometheus Queries

```promql
# Total builds
sum(jenkins_job_builds_total)

# Failed builds (5m)
sum(increase(jenkins_job_builds_failure_total[5m]))

# Average build duration
avg(jenkins_job_last_build_duration_seconds)

# Executor utilization
(jenkins_executor_busy / jenkins_executor_count) * 100

# Queue size
jenkins_queue_size
```

### SSH Access

```bash
# Jenkins
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@JENKINS_IP

# Monitoring
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@MONITORING_IP
```

### Quick Troubleshooting

```bash
# Restart Jenkins
ssh ubuntu@JENKINS_IP 'sudo systemctl restart jenkins'

# Restart Prometheus
ssh ubuntu@MONITORING_IP 'sudo systemctl restart prometheus'

# Check logs
ssh ubuntu@JENKINS_IP 'sudo journalctl -u jenkins -n 50'
```

---

## Common First-Time Issues

### "No Data" in Grafana

**Solution:**
1. Check time range (top right)
2. Run a Jenkins build first
3. Wait 30 seconds for metrics to propagate
4. Refresh Grafana

### Alert Not Firing

**Solution:**
1. Check Prometheus → Alerts
2. Verify alert rules loaded: `sudo systemctl restart prometheus`
3. Run failure drill again
4. Wait 2-3 minutes for evaluation

### No Traces in Jaeger

**Solution:**
1. Configure OpenTelemetry plugin in Jenkins
2. See: `configs/jenkins/jenkins-otel-config.md`
3. Restart Jenkins
4. Run pipeline again

### Jenkins Metrics Not Available

**Solution:**
```bash
# Check plugin
# Jenkins → Manage Plugins → Installed → "Prometheus"

# Check endpoint
curl http://JENKINS_IP:8080/prometheus

# Should see metrics
```

---

## Next Steps

After successful setup:

1. ✅ Review the full README.md
2. ✅ Study the runbooks: `configs/prometheus/RUNBOOKS.md`
3. ✅ Explore dashboard panels
4. ✅ Try different failure scenarios
5. ✅ Complete the battle log
6. ✅ Customize alerts and dashboards

---

## Cleanup (When Done)

```bash
./scripts/cleanup.sh

# This destroys all resources
# Make sure you've saved your battle log!
```

---

## Getting Help

### Check Verification

```bash
./scripts/verify-setup.sh
```

### View Logs

```bash
# Jenkins
ssh ubuntu@JENKINS_IP 'sudo journalctl -u jenkins -f'

# Prometheus
ssh ubuntu@MONITORING_IP 'sudo journalctl -u prometheus -f'

# OTel Collector
ssh ubuntu@MONITORING_IP 'sudo journalctl -u otelcol -f'
```

### Common Commands

```bash
# Check service status
sudo systemctl status jenkins
sudo systemctl status prometheus
sudo systemctl status grafana-server

# Restart services
sudo systemctl restart jenkins
sudo systemctl restart prometheus

# View configs
sudo cat /etc/prometheus/prometheus.yml
sudo cat /etc/prometheus/alert_rules.yml
```

---

## Pro Tips

1. **Take Screenshots** as you go through the drill
2. **Open Multiple Tabs** to watch all systems simultaneously
3. **Document Everything** in your battle log
4. **Experiment** with different failure types
5. **Adjust Thresholds** to see alerts fire sooner/later
6. **Create Custom Dashboards** based on your needs

---

## Success Checklist

- [ ] Deployed infrastructure
- [ ] Accessed all services
- [ ] Created sample pipeline
- [ ] Saw metrics in Prometheus
- [ ] Saw data in Grafana dashboard
- [ ] Saw traces in Jaeger
- [ ] Ran failure drill
- [ ] Observed alert firing
- [ ] Collected screenshots
- [ ] Started battle log

---

**You're ready! Good luck with the challenge! 🎉**

*Time to deployment: ~15 minutes*  
*Time to first drill: ~20 minutes total*  
*Time to completion: ~2-3 hours*

---

## Quick Support Matrix

| Issue | Where to Look | Fix Command |
|-------|---------------|-------------|
| Jenkins down | `systemctl status jenkins` | `sudo systemctl restart jenkins` |
| No metrics | Jenkins → Plugins | Install Prometheus plugin |
| No dashboard data | Grafana → Data Sources | Verify Prometheus connection |
| No traces | Jenkins → Configure System | Configure OTel endpoint |
| Alert not firing | Prometheus → Alerts | Check alert_rules.yml |
| Can't SSH | AWS → Security Groups | Check SSH port 22 |

---

**Ready? Let's go! 🚀**

```bash
cd observability-challenge
./scripts/deploy.sh
```

