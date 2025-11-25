# 🎉 Jenkins Observability Challenge - Deployment Complete!

**Deployed:** November 24, 2025, 11:50 PM IST  
**Region:** ap-south-1 (Mumbai)  
**Instance Type:** c7i-flex.large

---

## ✅ What's Deployed and Working

### Infrastructure
- ✅ VPC with public subnet
- ✅ Security groups configured
- ✅ Jenkins VM (c7i-flex.large) - **RUNNING**
- ✅ Monitoring VM (c7i-flex.large) - **RUNNING**

### Services Status

| Service | Status | URL |
|---------|--------|-----|
| **Jenkins** | ✅ Running | http://13.127.76.67:8080 |
| **Prometheus** | ✅ Running | http://13.126.206.250:9090 |
| **Grafana** | ✅ Running | http://13.126.206.250:3000 |
| **Jaeger** | ✅ Running | http://13.126.206.250:16686 |
| **OTel Collector** | ⚠️ Needs Config | - |

### Configuration Status
- ✅ Prometheus configured with Jenkins scraping
- ✅ Alert rules loaded (8 alerts)
- ⚠️  Grafana needs initial setup (manual)
- ⚠️  OpenTelemetry needs configuration (manual)

---

## 🔐 Access Credentials

### Jenkins
- **URL:** http://13.127.76.67:8080
- **Username:** `admin`
- **Password:** `a743764e0ff7477aaaacc775360335ac`

### Grafana
- **URL:** http://13.126.206.250:3000
- **Username:** `admin`
- **Password:** `admin` (change on first login)

### Prometheus
- **URL:** http://13.126.206.250:9090
- No authentication required

### Jaeger
- **URL:** http://13.126.206.250:16686
- No authentication required

---

## 🔑 SSH Access

```bash
# Jenkins Server
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@13.127.76.67

# Monitoring Server
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@13.126.206.250
```

**Private IPs:**
- Jenkins: 10.0.1.18
- Monitoring: 10.0.1.242

---

## 📋 Next Steps (Manual Setup Required)

### Step 1: Complete Jenkins Setup (5 minutes)

1. **Access Jenkins:** http://13.127.76.67:8080

2. **Login:**
   - Username: `admin`
   - Password: `a743764e0ff7477aaaacc775360335ac`

3. **Install Suggested Plugins**
   - Click "Install suggested plugins"
   - Wait for installation to complete

4. **Verify Prometheus Plugin:**
   - Go to **Manage Jenkins** → **Manage Plugins** → **Installed**
   - Search for "Prometheus metrics plugin"
   - Should be already installed

5. **Verify Metrics Endpoint:**
   - Visit: http://13.127.76.67:8080/prometheus
   - You should see Jenkins metrics like `jenkins_node_online_total`, etc.

---

### Step 2: Configure Grafana (5 minutes)

1. **Access Grafana:** http://13.126.206.250:3000

2. **First Login:**
   - Username: `admin`
   - Password: `admin`
   - You'll be prompted to change the password - **set a new one**

3. **Add Prometheus Data Source:**
   - Go to **Configuration** (⚙️) → **Data Sources**
   - Click **Add data source**
   - Select **Prometheus**
   - Settings:
     - **Name:** Prometheus
     - **URL:** `http://localhost:9090`
     - **Access:** Server (default)
   - Click **Save & Test** - should show green success

4. **Import Jenkins Dashboard:**
   - Go to **Dashboards** (☰) → **Import**
   - Click **Upload JSON file**
   - Upload: `configs/grafana/jenkins-dashboard.json`
   - Select **Prometheus** as data source
   - Click **Import**

5. **Verify Dashboard:**
   - Dashboard should load with panels (may show "No Data" until builds run)

---

### Step 3: Configure OpenTelemetry in Jenkins (10 minutes)

1. **Install OpenTelemetry Plugin:**
   - **Manage Jenkins** → **Manage Plugins** → **Available**
   - Search: "OpenTelemetry"
   - Check the box and click **Install without restart**

2. **Configure Plugin:**
   - **Manage Jenkins** → **Configure System**
   - Scroll to **OpenTelemetry** section
   - Configuration:
     ```
     OTLP Endpoint: http://10.0.1.242:4317
     Protocol: grpc
     Export Traces: ✅
     Export Metrics: ✅
     Export Logs: ✅
     Service Name: jenkins-ci
     Service Namespace: ci-cd
     ```
   - **Save**

3. **Detailed Instructions:**
   - See: `configs/jenkins/jenkins-otel-config.md`

---

### Step 4: Create Jenkins Pipelines (10 minutes)

#### A. Sample Pipeline

1. **New Item** → Name: "sample-pipeline" → **Pipeline**
2. **Pipeline Script:** Copy entire content from `pipelines/sample-pipeline.groovy`
3. **Save**

#### B. Failure Drill Pipeline

1. **New Item** → Name: "failure-drill" → **Pipeline**
2. **Pipeline Script:** Copy from `pipelines/failure-drill-pipeline.groovy`
3. **Save**

#### C. Load Test Pipeline (Optional)

1. **New Item** → Name: "load-test" → **Pipeline**
2. **Pipeline Script:** Copy from `pipelines/load-test-pipeline.groovy`
3. **Save**

---

### Step 5: Test the Setup (5 minutes)

1. **Run Sample Pipeline:**
   - Go to "sample-pipeline"
   - Click **Build Now**
   - Watch console output

2. **Check Prometheus Metrics:**
   - Open: http://13.126.206.250:9090
   - Query: `jenkins_job_builds_total`
   - Should see results

3. **Check Grafana Dashboard:**
   - Open your Jenkins dashboard
   - Should show build data (after 30 seconds)

4. **Check Jaeger (if OTel configured):**
   - Open: http://13.126.206.250:16686
   - Service: `jenkins-ci`
   - Should see traces

---

### Step 6: Run Failure Drill (10 minutes)

1. **Open "failure-drill" Pipeline**

2. **Build with Parameters:**
   - Failure Type: `EXIT_CODE`
   - Failure Stage: `BUILD`
   - Delay: `10` seconds

3. **Click "Build"**

4. **Observe:**
   - Jenkins console (watch it fail)
   - Prometheus: query `jenkins_job_builds_failure_total`
   - Grafana: "Failed Builds (5m)" panel
   - Prometheus Alerts: http://13.126.206.250:9090/alerts
   - Jaeger: traces for failed build

5. **Take Screenshots:**
   - Prometheus metrics showing failure
   - Alert firing
   - Grafana dashboard
   - Jaeger trace
   - Jenkins console error

---

### Step 7: Complete Battle Log (45 minutes)

1. **Open Template:**
   - `docs/BATTLE_LOG_TEMPLATE.md`

2. **Fill Out All Sections:**
   - Which metric caught the issue first?
   - Did alerts fire?
   - Were dashboards helpful?
   - Root cause from logs?
   - Trace view analysis?
   - What would you trust in production?

3. **Include Screenshots**

---

## 🔍 Verification Commands

### Check All Services
```bash
# Jenkins
curl -s http://13.127.76.67:8080 | grep -i jenkins

# Prometheus
curl -s http://13.126.206.250:9090/-/healthy

# Grafana
curl -s http://13.126.206.250:3000/api/health | jq .

# Jaeger
curl -s http://13.126.206.250:16686/ | grep -i jaeger
```

### Check Jenkins Metrics
```bash
curl -s http://13.127.76.67:8080/prometheus | grep jenkins_
```

### Check Prometheus Targets
```bash
# Should show Jenkins target as "UP"
open http://13.126.206.250:9090/targets
```

### Check Prometheus Alerts
```bash
# View configured alerts
open http://13.126.206.250:9090/alerts
```

---

## 📊 Key Prometheus Queries

```promql
# Total builds
sum(jenkins_job_builds_total)

# Failed builds (last 5m)
sum(increase(jenkins_job_builds_failure_total[5m]))

# Success rate
sum(rate(jenkins_job_builds_success_total[5m])) / sum(rate(jenkins_job_builds_total[5m]))

# Average build duration
avg(jenkins_job_last_build_duration_seconds)

# Executor utilization
(jenkins_executor_busy / jenkins_executor_count) * 100

# Queue size
jenkins_queue_size

# Is Jenkins up?
up{job="jenkins"}
```

---

## 🐛 Troubleshooting

### Jenkins Not Accessible
```bash
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@13.127.76.67
sudo systemctl status jenkins
sudo journalctl -u jenkins -f
```

### Prometheus Not Scraping Jenkins
```bash
# Check Prometheus targets
open http://13.126.206.250:9090/targets

# Check connectivity
ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@13.126.206.250
telnet 10.0.1.18 8080

# Check Prometheus config
sudo cat /etc/prometheus/prometheus.yml
```

### Grafana Shows "No Data"
1. Check if Prometheus datasource is connected (green check)
2. Run a Jenkins build first
3. Wait 30 seconds for metrics to propagate
4. Adjust time range in Grafana (top right)

### No Traces in Jaeger
1. Ensure OpenTelemetry plugin is installed in Jenkins
2. Verify OTel Collector is running:
   ```bash
   ssh -i ~/.ssh/jenkins-observability-key.pem ubuntu@13.126.206.250
   sudo systemctl status otelcol
   ```
3. Check OTel endpoint configuration in Jenkins
4. Run a pipeline and wait 1-2 minutes

---

## 💰 Cost Information

**Current Setup:**
- 2x c7i-flex.large instances
- 30GB + 50GB EBS storage
- Estimated cost: ~$0.10-0.15/hour
- **For 3-hour challenge: ~$0.30-0.45 total**

**To Minimize Costs:**
- Complete the challenge quickly
- Run cleanup script when done:
  ```bash
  cd observability-challenge
  ./scripts/cleanup.sh
  ```

---

## 🧹 Cleanup (When Complete)

**IMPORTANT:** Don't forget to destroy resources after completing the challenge!

```bash
cd /Users/shubham.arora/Downloads/Terraform-Drift_issue/observability-challenge
./scripts/cleanup.sh
```

This will:
- Destroy all EC2 instances
- Delete VPC, subnets, security groups
- Optionally delete SSH key pair
- Remove Terraform state

---

## 📚 Helpful Resources

- **Main README:** `README.md` - Complete documentation
- **Quick Start:** `docs/QUICK_START_GUIDE.md` - Fast setup guide
- **Runbooks:** `configs/prometheus/RUNBOOKS.md` - Alert response guides
- **OTel Config:** `configs/jenkins/jenkins-otel-config.md` - Tracing setup
- **Battle Log:** `docs/BATTLE_LOG_TEMPLATE.md` - Submission template

---

## ✅ Setup Checklist

- [x] Infrastructure deployed
- [x] Jenkins running
- [x] Prometheus running and scraping
- [x] Grafana running
- [x] Jaeger running
- [ ] Jenkins initial setup completed
- [ ] Grafana configured and dashboard imported
- [ ] OpenTelemetry configured
- [ ] Sample pipeline created
- [ ] Failure drill pipeline created
- [ ] Test build executed
- [ ] Metrics verified in Prometheus
- [ ] Dashboard shows data
- [ ] Failure drill executed
- [ ] Screenshots captured
- [ ] Battle log completed

---

## 🎯 Success Criteria

You've successfully completed when:

1. ✅ Can access all services via browser
2. ✅ Jenkins runs builds successfully
3. ✅ Prometheus shows Jenkins metrics
4. ✅ Grafana dashboard displays build data
5. ✅ Alerts are configured and tested
6. ✅ Failure drill executed and observed
7. ✅ All systems responded to failure
8. ✅ Battle log completed with analysis

---

## 🎉 You're Ready!

Everything is deployed and ready for you to complete the manual setup steps above.

**Estimated time to complete:**
- Manual setup: 30-40 minutes
- Testing and failure drill: 20-30 minutes
- Battle log: 45-60 minutes
- **Total: 2-2.5 hours**

**Good luck with your challenge! 🚀**

---

**Deployment ID:** jenkins-observability-20251124  
**Last Updated:** November 24, 2025, 11:50 PM IST

