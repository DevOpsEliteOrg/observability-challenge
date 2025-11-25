# Jenkins Observability Challenge - Alert Runbooks

This document provides detailed runbooks for each Prometheus alert defined in the observability challenge.

---

## 🚨 Alert 1: Jenkins Slow Build

### Alert Definition
```yaml
jenkins_job_last_build_duration_seconds > 300
```

### 🔍 Cause
Build is taking longer than 5 minutes (300 seconds). Common causes include:
- Heavy computational tasks in build steps
- Large artifact compilation
- Network latency (downloading dependencies, pushing artifacts)
- Inefficient test suites
- Resource contention on Jenkins executor
- Database or external service slowness
- Parallel build configuration issues

### 🔬 Diagnose

1. **Check Jenkins Job Console Output**
   ```bash
   # View the specific job's last build console output
   # Jenkins UI: Job → Build #X → Console Output
   ```

2. **Query Prometheus for Build Duration Trend**
   ```promql
   # Check build duration over time
   jenkins_job_last_build_duration_seconds{jenkins_job="your-job"}
   
   # Compare with average
   avg_over_time(jenkins_job_last_build_duration_seconds{jenkins_job="your-job"}[1h])
   ```

3. **Check Executor Load**
   ```promql
   # Check if executors are overloaded
   jenkins_executor_busy / jenkins_executor_count
   ```

4. **Check System Resources on Jenkins Node**
   ```bash
   ssh jenkins-server
   top
   df -h
   iostat -x 1
   ```

5. **Review Build Stage Timing**
   - Check Jenkins Pipeline Stage View
   - Identify which stage is taking the most time
   - Use OpenTelemetry traces to see detailed spans

### ✅ Fix

**Immediate Actions:**
1. Cancel the slow build if it's clearly hung
2. Restart the build with verbose logging
3. Check if the issue is reproducible

**Short-term Fixes:**
1. **Optimize Build Steps:**
   ```groovy
   // Add timeout to prevent indefinite hangs
   timeout(time: 10, unit: 'MINUTES') {
       sh 'your-build-command'
   }
   ```

2. **Parallelize Build Stages:**
   ```groovy
   parallel {
       stage('Unit Tests') {
           steps { sh 'npm test' }
       }
       stage('Integration Tests') {
           steps { sh 'npm run integration' }
       }
   }
   ```

3. **Cache Dependencies:**
   ```groovy
   // Use workspace caching
   dir('.npm-cache') {
       sh 'npm ci --cache .npm-cache'
   }
   ```

4. **Increase Executor Resources:**
   - Add more executors
   - Upgrade Jenkins node instance type

**Long-term Solutions:**
1. Implement incremental builds
2. Use distributed builds with Jenkins agents
3. Optimize test suites (remove redundant tests)
4. Use artifact caching (Artifactory, Nexus)
5. Profile and optimize build scripts

### 🛡️ Prevent

1. **Set Build Timeouts:**
   ```groovy
   pipeline {
       options {
           timeout(time: 30, unit: 'MINUTES')
       }
   }
   ```

2. **Monitor Build Duration Trends:**
   - Create Grafana dashboard panel for build duration
   - Set up alerts for gradual slowdown (not just sudden spikes)

3. **Implement Build Performance Testing:**
   - Track build metrics over time
   - Benchmark after major changes
   - Review slow builds weekly

4. **Resource Planning:**
   - Right-size Jenkins nodes
   - Use dedicated build agents for heavy jobs
   - Implement auto-scaling for cloud agents

---

## 🚨 Alert 2: Build Failure Spike

### Alert Definition
```yaml
increase(jenkins_job_builds_failure_total[5m]) > 1
```

### 🔍 Cause
Multiple builds failing in a short time window. Common causes include:
- Code defects in recent commits
- Breaking changes in dependencies
- Environmental issues (services down, credentials expired)
- Flaky tests
- Infrastructure problems
- Configuration drift
- External API failures

### 🔬 Diagnose

1. **Identify Failed Jobs**
   ```promql
   # Show all failed jobs in last 5 minutes
   increase(jenkins_job_builds_failure_total[5m]) > 0
   ```

2. **Check Build Console Output**
   - Go to Jenkins UI → Job → Latest Failed Build → Console Output
   - Look for error messages, stack traces, exit codes

3. **Compare with Previous Successful Build**
   ```bash
   # What changed between last success and first failure?
   # Check Git commits, dependency versions, environment
   ```

4. **Check for Pattern**
   ```promql
   # Is it all jobs or specific ones?
   sum by (jenkins_job) (increase(jenkins_job_builds_failure_total[5m]))
   ```

5. **Review Recent Changes**
   - Check Git history: `git log --since="5 minutes ago"`
   - Review recent deployments
   - Check for infrastructure changes

6. **Check External Dependencies**
   ```bash
   # Are external services responding?
   curl -I https://your-api.com/health
   
   # Check database connectivity
   nc -zv database-host 5432
   ```

### ✅ Fix

**Immediate Actions:**
1. **Stop the Bleeding:**
   - Pause new builds if failure rate is high
   - Roll back recent changes if identified

2. **Quick Fixes:**
   ```groovy
   // Add retry logic for flaky steps
   retry(3) {
       sh 'flaky-command'
   }
   ```

3. **Fix Code Issues:**
   - If tests are failing, fix the code
   - Create hotfix branch
   - Fast-track the fix through CI/CD

4. **Fix Environmental Issues:**
   ```bash
   # Restart services
   systemctl restart your-service
   
   # Refresh credentials
   jenkins-cli update-credentials
   
   # Clear cache
   rm -rf ~/.m2/repository
   ```

**Root Cause Fixes:**
1. Fix the actual bug in code
2. Update failing tests
3. Fix infrastructure configuration
4. Update expired credentials
5. Patch dependency versions

### 🛡️ Prevent

1. **Implement Better Testing:**
   ```groovy
   // Smoke test before full pipeline
   stage('Smoke Test') {
       steps {
           sh './quick-sanity-check.sh'
       }
   }
   ```

2. **Use Feature Flags:**
   - Deploy code with features disabled
   - Enable gradually after validation

3. **Implement Canary Deployments:**
   - Test on subset of infrastructure first
   - Monitor before full rollout

4. **Improve Test Reliability:**
   - Fix flaky tests immediately
   - Add retry logic only where appropriate
   - Use test containers for isolation

5. **Set Up Pre-commit Hooks:**
   ```bash
   # Run tests locally before commit
   npm test
   ```

6. **Dependency Management:**
   - Pin dependency versions
   - Use lock files (package-lock.json, Pipfile.lock)
   - Automated dependency updates with testing

---

## 🚨 Alert 3: Executor Saturation

### Alert Definition
```yaml
(jenkins_executor_busy / jenkins_executor_count) > 0.9
```

### 🔍 Cause
More than 90% of Jenkins executors are busy. Common causes include:
- Build volume spike
- Long-running builds
- Insufficient executor capacity
- Stuck/hung builds consuming executors
- Poor pipeline design (no parallelization)
- Misconfigured agent labels

### 🔬 Diagnose

1. **Check Current Executor Status**
   ```promql
   # Current busy executors
   jenkins_executor_busy
   
   # Total executors
   jenkins_executor_count
   
   # Saturation percentage
   (jenkins_executor_busy / jenkins_executor_count) * 100
   ```

2. **Check Jenkins Build Queue**
   ```promql
   # How many jobs waiting?
   jenkins_queue_size
   ```

3. **Identify Long-Running Builds**
   - Jenkins UI → Manage Jenkins → Build Executor Status
   - Look for builds running longer than expected

4. **Check for Stuck Builds**
   ```bash
   # SSH to Jenkins server
   # Check processes
   ps aux | grep jenkins
   ```

5. **Review Build History**
   ```promql
   # Build rate over time
   rate(jenkins_job_builds_total[5m])
   ```

### ✅ Fix

**Immediate Actions:**

1. **Kill Stuck Builds:**
   - Jenkins UI → Build Executor Status → Terminate hung builds
   
2. **Temporarily Increase Executors:**
   ```bash
   # Jenkins UI: Manage Jenkins → Configure System → # of executors
   # Increase from 2 to 4 (temporary)
   ```

3. **Add Cloud Agents (If using Kubernetes/Docker):**
   ```groovy
   // Jenkins Configuration as Code
   jenkins:
     clouds:
       - kubernetes:
           containerCapStr: "100"
   ```

**Long-term Solutions:**

1. **Scale Jenkins Infrastructure:**
   - Add more Jenkins agents
   - Use cloud-based auto-scaling agents
   - Implement Docker/Kubernetes agents

2. **Optimize Pipeline Parallelization:**
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Parallel Tests') {
               parallel {
                   stage('Unit') { steps { sh 'npm test' } }
                   stage('Integration') { steps { sh 'npm run integration' } }
                   stage('E2E') { steps { sh 'npm run e2e' } }
               }
           }
       }
   }
   ```

3. **Implement Build Throttling:**
   ```groovy
   // Throttle concurrent builds
   options {
       throttle(['category': 'deployment', 'maxConcurrentPerNode': 1])
   }
   ```

4. **Use Labels for Agent Allocation:**
   ```groovy
   // Run heavy builds on specific agents
   agent { label 'heavy-builds' }
   ```

### 🛡️ Prevent

1. **Capacity Planning:**
   - Monitor executor utilization trends
   - Plan for peak build times
   - Use auto-scaling cloud agents

2. **Build Scheduling:**
   ```groovy
   // Schedule heavy builds during off-hours
   triggers {
       cron('H 2 * * *')  // 2 AM daily
   }
   ```

3. **Implement Queue Priority:**
   - Use Jenkins Priority Sorter plugin
   - Prioritize critical builds

4. **Set Build Timeouts:**
   ```groovy
   options {
       timeout(time: 30, unit: 'MINUTES')
   }
   ```

---

## 🚨 Alert 4: Queue Backlog

### Alert Definition
```yaml
jenkins_queue_size > 5
```

### 🔍 Cause
More than 5 jobs waiting in Jenkins queue. Common causes include:
- All executors busy (see Executor Saturation)
- Build trigger storm (many commits at once)
- Scheduled builds all starting simultaneously
- Insufficient Jenkins capacity
- Blocked jobs (missing agents with specific labels)

### 🔬 Diagnose

1. **Check Queue Status**
   ```promql
   # Current queue size
   jenkins_queue_size
   
   # Queue wait time
   jenkins_queue_waiting
   ```

2. **View Jenkins Queue**
   - Jenkins UI → Build Queue (left sidebar)
   - Check why jobs are waiting

3. **Check Executor Availability**
   ```promql
   # Available executors
   jenkins_executor_idle
   
   # Busy executors
   jenkins_executor_busy
   ```

4. **Identify Job Types in Queue**
   - Are they all the same job?
   - Do they require specific agent labels?

5. **Check for Blocked Builds**
   - Look for "Waiting for next available executor" messages
   - Check for label mismatches

### ✅ Fix

**Immediate Actions:**

1. **Cancel Non-Critical Builds:**
   - Manually cancel lower-priority queued builds
   - Let critical builds complete first

2. **Add Temporary Executors:**
   - Increase executor count temporarily
   - Spin up additional Jenkins agents

3. **Prioritize Queue:**
   ```groovy
   // Mark urgent builds with priority
   properties([
       pipelineTriggers([]),
       priority(10)  // Higher number = higher priority
   ])
   ```

**Long-term Solutions:**

1. **Scale Jenkins:**
   - Add permanent agents
   - Implement auto-scaling

2. **Optimize Build Triggers:**
   ```groovy
   // Prevent build storms
   options {
       disableConcurrentBuilds()
   }
   
   // Batch commits
   triggers {
       pollSCM('H/15 * * * *')  // Check every 15 minutes
   }
   ```

3. **Use Pipeline Libraries:**
   - Reduce duplicate builds
   - Share common pipeline code

### 🛡️ Prevent

1. **Load Balancing:**
   - Distribute builds across multiple Jenkins instances
   - Use folder-based executor allocation

2. **Smart Scheduling:**
   ```groovy
   // Spread scheduled builds
   triggers {
       cron('H H(0-7) * * *')  // Random time between midnight and 7 AM
   }
   ```

3. **Implement Build Throttling:**
   - Limit concurrent builds per project
   - Use throttle plugin

4. **Monitor Trends:**
   - Track queue depth over time
   - Capacity plan based on growth

---

## 📊 Observability Best Practices

### Metric Priority
1. **High Priority (Check First):**
   - `jenkins_job_builds_failure_total` - Failures are critical
   - `jenkins_queue_size` - Indicates capacity issues
   - `up{job="jenkins"}` - Is Jenkins even running?

2. **Medium Priority:**
   - `jenkins_job_last_build_duration_seconds` - Performance degradation
   - `jenkins_executor_busy/jenkins_executor_count` - Capacity utilization

3. **Low Priority:**
   - Build success rate trends
   - Historical performance metrics

### Alert Response SLA
- **Critical (P0):** Respond within 5 minutes
  - Jenkins Down
  - Build Failure Spike in production
  
- **Warning (P1):** Respond within 15 minutes
  - Executor Saturation
  - Queue Backlog
  - Slow Builds

- **Info (P2):** Review during business hours
  - Gradual performance degradation
  - Capacity planning alerts

### Incident Response Checklist
1. ✅ Check if alert is real or false positive
2. ✅ Assess impact (how many users/builds affected?)
3. ✅ Check related metrics and logs
4. ✅ Review recent changes (code, config, infrastructure)
5. ✅ Implement immediate fix/mitigation
6. ✅ Communicate status to team
7. ✅ Verify fix resolved the issue
8. ✅ Document root cause
9. ✅ Schedule post-mortem
10. ✅ Implement preventive measures

---

## 🔗 Quick Links

- Jenkins UI: http://jenkins:8080
- Prometheus: http://prometheus:9090
- Grafana: http://grafana:3000
- Jaeger: http://jaeger:16686
- Alert Rules: `/etc/prometheus/alert_rules.yml`
- Prometheus Config: `/etc/prometheus/prometheus.yml`

---

**Last Updated:** 2025-11-24  
**Version:** 1.0  
**Owner:** SRE Team

