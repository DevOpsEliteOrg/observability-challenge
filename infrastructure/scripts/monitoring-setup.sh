#!/bin/bash
set -e

# Monitoring Stack Installation Script
# Installs: Prometheus, Grafana, Jaeger, OpenTelemetry Collector

echo "==================================="
echo "Monitoring Stack Setup Starting"
echo "==================================="

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y curl wget apt-transport-https software-properties-common

#==================================
# PROMETHEUS INSTALLATION
#==================================
echo "Installing Prometheus..."

# Create prometheus user
useradd --no-create-home --shell /bin/false prometheus || true

# Download and install Prometheus
PROMETHEUS_VERSION="2.48.0"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

# Copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus

# Copy console files
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus
chown -R prometheus:prometheus /etc/prometheus/consoles
chown -R prometheus:prometheus /etc/prometheus/console_libraries

# Create Prometheus systemd service
cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

#==================================
# GRAFANA INSTALLATION
#==================================
echo "Installing Grafana..."

# Add Grafana GPG key and repository
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

# Install Grafana
apt-get update
apt-get install -y grafana

# Enable and start Grafana
systemctl enable grafana-server
systemctl start grafana-server

#==================================
# JAEGER INSTALLATION
#==================================
echo "Installing Jaeger..."

# Download and install Jaeger all-in-one
JAEGER_VERSION="1.51.0"
wget https://github.com/jaegertracing/jaeger/releases/download/v${JAEGER_VERSION}/jaeger-${JAEGER_VERSION}-linux-amd64.tar.gz -O /tmp/jaeger.tar.gz
cd /tmp
tar -xvf jaeger.tar.gz
cp jaeger-${JAEGER_VERSION}-linux-amd64/jaeger-all-in-one /usr/local/bin/

# Create jaeger user
useradd --no-create-home --shell /bin/false jaeger || true

# Create Jaeger systemd service
cat > /etc/systemd/system/jaeger.service <<'EOF'
[Unit]
Description=Jaeger All-in-One
After=network.target

[Service]
Type=simple
User=jaeger
ExecStart=/usr/local/bin/jaeger-all-in-one \
    --collector.otlp.enabled=true

[Install]
WantedBy=multi-user.target
EOF

#==================================
# OPENTELEMETRY COLLECTOR INSTALLATION
#==================================
echo "Installing OpenTelemetry Collector..."

# Download and install OTel Collector
OTEL_VERSION="0.91.0"
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_amd64.tar.gz -O /tmp/otelcol.tar.gz
cd /tmp
tar -xvf otelcol.tar.gz
cp otelcol /usr/local/bin/otelcol-contrib
chmod +x /usr/local/bin/otelcol-contrib

# Create otel user
useradd --no-create-home --shell /bin/false otelcol || true

# Create OTel config directory
mkdir -p /etc/otelcol

# Create OpenTelemetry Collector systemd service
cat > /etc/systemd/system/otelcol.service <<'EOF'
[Unit]
Description=OpenTelemetry Collector
After=network.target

[Service]
Type=simple
User=otelcol
ExecStart=/usr/local/bin/otelcol-contrib --config=/etc/otelcol/config.yaml

[Install]
WantedBy=multi-user.target
EOF

#==================================
# START ALL SERVICES
#==================================
echo "Starting all services..."

systemctl daemon-reload

# Start Prometheus
systemctl enable prometheus
systemctl start prometheus

# Start Jaeger
systemctl enable jaeger
systemctl start jaeger

# Note: OTel collector will be started after configuration

#==================================
# PRINT STATUS
#==================================
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "==================================="
echo "Monitoring Stack Installation Complete!"
echo "==================================="
echo "Prometheus: http://${PUBLIC_IP}:9090"
echo "Grafana: http://${PUBLIC_IP}:3000 (admin/admin)"
echo "Jaeger UI: http://${PUBLIC_IP}:16686"
echo "OTel Collector: ${PUBLIC_IP}:4317 (gRPC), ${PUBLIC_IP}:4318 (HTTP)"
echo "==================================="
echo ""
echo "Service Status:"
systemctl status prometheus --no-pager | grep Active || true
systemctl status grafana-server --no-pager | grep Active || true
systemctl status jaeger --no-pager | grep Active || true
echo "==================================="

# Save info to file
cat > /tmp/monitoring-info.txt <<EOF
Prometheus: http://${PUBLIC_IP}:9090
Grafana: http://${PUBLIC_IP}:3000
  Username: admin
  Password: admin
Jaeger UI: http://${PUBLIC_IP}:16686
OTel Collector: ${PUBLIC_IP}:4317 (gRPC), ${PUBLIC_IP}:4318 (HTTP)
EOF

echo "Connection info saved to /tmp/monitoring-info.txt"

