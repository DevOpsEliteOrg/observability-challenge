# Jenkins OpenTelemetry Plugin Configuration

This guide explains how to configure the OpenTelemetry plugin in Jenkins to export traces to the OTel Collector.

## Prerequisites

1. Jenkins with OpenTelemetry plugin installed
2. OTel Collector running on monitoring server
3. Network connectivity between Jenkins and OTel Collector

## Configuration Steps

### 1. Install OpenTelemetry Plugin

**Via Jenkins UI:**
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Go to **Available** tab
3. Search for "OpenTelemetry"
4. Check **OpenTelemetry** plugin
5. Click **Install without restart**

**Via Jenkins CLI:**
```bash
java -jar jenkins-cli.jar -s http://jenkins:8080/ -auth admin:password install-plugin opentelemetry
```

### 2. Configure OpenTelemetry Plugin

**Via Jenkins UI:**

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **OpenTelemetry** section
3. Configure the following:

#### Basic Configuration

- **OTLP Endpoint**: `http://MONITORING_SERVER_IP:4317` (replace with actual IP)
- **OTLP Protocol**: `grpc`
- **Authentication**: None (or configure if needed)
- **Export Traces**: ✅ Enabled
- **Export Metrics**: ✅ Enabled
- **Export Logs**: ✅ Enabled

#### Service Configuration

- **Service Name**: `jenkins-ci`
- **Service Namespace**: `ci-cd`
- **Service Instance ID**: `jenkins-primary`

#### Resource Attributes (Optional but Recommended)

Add custom attributes:
```
environment=production
cluster=jenkins-observability
region=us-east-1
```

#### Advanced Settings

- **Sampling Ratio**: `1.0` (100% - sample all traces)
- **Flush Interval**: `5000` ms
- **Max Queue Size**: `2048`
- **Max Export Batch Size**: `512`

#### Ignored Steps (Performance Optimization)

Add steps you don't want to trace:
```
echo
sleep
```

### 3. Configuration as Code (JCasC)

If using Jenkins Configuration as Code, add this to your `jenkins.yaml`:

```yaml
unclassified:
  openTelemetry:
    # OTLP Endpoint
    endpoint: "http://MONITORING_SERVER_IP:4317"
    
    # Protocol (grpc or http/protobuf)
    exporterType: "grpc"
    
    # Observability signals
    exportTraces: true
    exportMetrics: true
    exportLogs: true
    
    # Service identification
    serviceName: "jenkins-ci"
    serviceNamespace: "ci-cd"
    
    # Resource attributes
    resourceAttributes:
      - key: "environment"
        value: "production"
      - key: "cluster"
        value: "jenkins-observability"
    
    # Sampling
    tracesEnabled: true
    
    # Steps to ignore
    ignoredSteps:
      - "echo"
      - "sleep"
```

### 4. Verify Configuration

#### Check OTel Plugin Status

1. Go to **Manage Jenkins** → **System Information**
2. Search for "opentelemetry"
3. Verify plugin is loaded

#### Test Connection

Run a simple pipeline to test:

```groovy
pipeline {
    agent any
    stages {
        stage('Test OTel') {
            steps {
                echo "Testing OpenTelemetry integration"
                sh 'echo "Hello from Jenkins"'
            }
        }
    }
}
```

#### Verify Traces in Jaeger

1. Open Jaeger UI: `http://MONITORING_SERVER_IP:16686`
2. Select Service: `jenkins-ci`
3. Click **Find Traces**
4. You should see the test pipeline execution

## What Gets Traced?

The OpenTelemetry plugin automatically creates spans for:

### Pipeline Execution Spans

1. **Job Span** - Overall pipeline execution
   - Span Name: Job name (e.g., `my-pipeline`)
   - Attributes:
     - `jenkins.job.name`
     - `jenkins.build.number`
     - `jenkins.build.url`
     - `jenkins.user.id`

2. **Stage Spans** - Each pipeline stage
   - Span Name: Stage name
   - Attributes:
     - `jenkins.stage.name`
     - `jenkins.stage.id`

3. **Step Spans** - Individual pipeline steps
   - Span Name: Step name (e.g., `sh`, `git`, `junit`)
   - Attributes:
     - `jenkins.step.name`
     - `jenkins.step.type`
     - `jenkins.step.id`

### SCM Operations

- Git clone/checkout
- SVN operations
- Other SCM plugins

### Build Steps

- Shell commands (`sh`)
- Batch commands (`bat`)
- Docker operations
- Maven/Gradle builds

### Test Operations

- JUnit test execution
- Test result publishing

### Artifact Operations

- Archive artifacts
- Publish artifacts

### Notifications

- Email notifications
- Slack notifications
- Other notification plugins

## Example Trace Hierarchy

```
jenkins-pipeline (Job Span)
├── Checkout (Stage Span)
│   └── git-clone (Step Span)
├── Build (Stage Span)
│   ├── sh: npm install (Step Span)
│   └── sh: npm run build (Step Span)
├── Test (Stage Span)
│   ├── sh: npm test (Step Span)
│   └── junit: publish results (Step Span)
└── Deploy (Stage Span)
    ├── sh: docker build (Step Span)
    └── sh: docker push (Step Span)
```

## Troubleshooting

### Traces Not Appearing in Jaeger

1. **Check OTel Collector Logs:**
   ```bash
   journalctl -u otelcol -f
   ```

2. **Check Jenkins Logs:**
   ```bash
   tail -f /var/log/jenkins/jenkins.log
   ```

3. **Verify Network Connectivity:**
   ```bash
   # From Jenkins server
   telnet MONITORING_SERVER_IP 4317
   ```

4. **Check OTel Plugin Configuration:**
   - Ensure endpoint URL is correct
   - Verify protocol (gRPC vs HTTP)
   - Check for authentication issues

### Partial or Missing Spans

1. **Check Sampling Rate:**
   - Ensure sampling ratio is 1.0 (100%)

2. **Check Ignored Steps:**
   - Verify you're not ignoring steps you want to trace

3. **Check OTel Collector Processing:**
   - Review processor configurations
   - Check for filters that might drop spans

### Performance Issues

1. **Reduce Sampling:**
   - Lower sampling ratio (e.g., 0.1 for 10%)

2. **Ignore More Steps:**
   - Add verbose/noisy steps to ignored list

3. **Increase Batch Size:**
   - Increase max batch size in OTel config

## Best Practices

1. **Use Meaningful Stage Names:**
   ```groovy
   stage('Build Application') {  // Good
       // vs
   stage('Build') {  // Less descriptive
   ```

2. **Add Custom Attributes:**
   ```groovy
   script {
       opentelemetry.addAttribute('app.version', '1.2.3')
       opentelemetry.addAttribute('deployment.target', 'production')
   }
   ```

3. **Use Consistent Naming:**
   - Use consistent stage/step names across pipelines
   - This helps with trace aggregation and analysis

4. **Monitor OTel Collector Health:**
   - Set up monitoring for the OTel Collector itself
   - Check for dropped spans

5. **Correlation with Logs:**
   - Use trace IDs in log messages
   - Helps correlate traces with logs

## Additional Resources

- [Jenkins OpenTelemetry Plugin Docs](https://plugins.jenkins.io/opentelemetry/)
- [OpenTelemetry Collector Docs](https://opentelemetry.io/docs/collector/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)

