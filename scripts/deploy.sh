#!/bin/bash

##############################################################################
# Jenkins Observability Challenge - Complete Deployment Script
# This script orchestrates the entire setup process
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

##############################################################################
# Functions
##############################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       Jenkins Observability Challenge - Deployment           ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}[$(date +'%H:%M:%S')] ▶ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install them and try again."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        echo "Please run: aws configure"
        exit 1
    fi
    
    echo "✅ All prerequisites met"
}

create_ssh_key() {
    print_step "Checking SSH key pair..."
    
    KEY_NAME="jenkins-observability-key"
    KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
    
    # Check if key already exists in AWS
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
        echo "✅ SSH key pair '$KEY_NAME' already exists in AWS"
        
        if [ ! -f "$KEY_FILE" ]; then
            print_warning "Key exists in AWS but not found locally at $KEY_FILE"
            echo "If you have the key file elsewhere, please copy it to: $KEY_FILE"
            read -p "Press Enter when ready..."
        fi
    else
        echo "Creating new SSH key pair..."
        aws ec2 create-key-pair \
            --key-name "$KEY_NAME" \
            --query 'KeyMaterial' \
            --output text > "$KEY_FILE"
        
        chmod 400 "$KEY_FILE"
        echo "✅ SSH key created: $KEY_FILE"
    fi
    
    export KEY_NAME
}

deploy_infrastructure() {
    print_step "Deploying infrastructure with Terraform..."
    
    cd "$PROJECT_ROOT/infrastructure"
    
    # Update terraform.tfvars with key name
    if [ -n "$KEY_NAME" ]; then
        sed -i.bak "s/key_name = .*/key_name = \"$KEY_NAME\"/" terraform.tfvars
        rm -f terraform.tfvars.bak
    fi
    
    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init
    
    # Plan
    echo "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    echo "Applying Terraform configuration..."
    read -p "Deploy infrastructure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
    
    terraform apply tfplan
    
    # Get outputs
    export JENKINS_IP=$(terraform output -raw jenkins_public_ip)
    export MONITORING_IP=$(terraform output -raw monitoring_public_ip)
    export JENKINS_PRIVATE_IP=$(terraform output -raw jenkins_private_ip)
    
    echo "✅ Infrastructure deployed"
    echo "Jenkins IP: $JENKINS_IP"
    echo "Monitoring IP: $MONITORING_IP"
    
    cd "$PROJECT_ROOT"
}

wait_for_instances() {
    print_step "Waiting for instances to be ready..."
    
    echo "Waiting for Jenkins server..."
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@"$JENKINS_IP" "echo 'connected'" &> /dev/null; do
        echo -n "."
        sleep 5
    done
    echo " ✅"
    
    echo "Waiting for Monitoring server..."
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@"$MONITORING_IP" "echo 'connected'" &> /dev/null; do
        echo -n "."
        sleep 5
    done
    echo " ✅"
    
    echo "Waiting for services to start (2 minutes)..."
    sleep 120
}

configure_prometheus() {
    print_step "Configuring Prometheus..."
    
    # Update Prometheus config with actual Jenkins IP
    local temp_config=$(mktemp)
    sed "s/JENKINS_PRIVATE_IP/$JENKINS_PRIVATE_IP/g" \
        "$PROJECT_ROOT/configs/prometheus/prometheus.yml" > "$temp_config"
    
    # Copy Prometheus configuration
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no \
        "$temp_config" \
        ubuntu@"$MONITORING_IP":/tmp/prometheus.yml
    
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no \
        "$PROJECT_ROOT/configs/prometheus/alert_rules.yml" \
        ubuntu@"$MONITORING_IP":/tmp/alert_rules.yml
    
    # Move configs to proper location and restart
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$MONITORING_IP" << 'EOF'
        sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml
        sudo mv /tmp/alert_rules.yml /etc/prometheus/alert_rules.yml
        sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
        sudo chown prometheus:prometheus /etc/prometheus/alert_rules.yml
        sudo systemctl restart prometheus
        sudo systemctl status prometheus --no-pager
EOF
    
    rm -f "$temp_config"
    echo "✅ Prometheus configured"
}

configure_otel_collector() {
    print_step "Configuring OpenTelemetry Collector..."
    
    # Copy OTel config
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no \
        "$PROJECT_ROOT/configs/otel/otel-collector-config.yaml" \
        ubuntu@"$MONITORING_IP":/tmp/otel-config.yaml
    
    # Move config and start OTel collector
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$MONITORING_IP" << 'EOF'
        sudo mv /tmp/otel-config.yaml /etc/otelcol/config.yaml
        sudo chown otelcol:otelcol /etc/otelcol/config.yaml
        sudo systemctl restart otelcol
        sudo systemctl status otelcol --no-pager
EOF
    
    echo "✅ OpenTelemetry Collector configured"
}

import_grafana_dashboard() {
    print_step "Importing Grafana dashboard..."
    
    # Wait for Grafana to be ready
    echo "Waiting for Grafana to be ready..."
    until curl -s "http://$MONITORING_IP:3000/api/health" &> /dev/null; do
        echo -n "."
        sleep 5
    done
    echo " ✅"
    
    # Add Prometheus as data source
    echo "Adding Prometheus data source..."
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
        "http://$MONITORING_IP:3000/api/datasources" || true
    
    # Import dashboard
    echo "Importing Jenkins dashboard..."
    local dashboard_json=$(cat "$PROJECT_ROOT/configs/grafana/jenkins-dashboard.json")
    
    curl -X POST \
        -H "Content-Type: application/json" \
        -u admin:admin \
        -d "{
            \"dashboard\": $dashboard_json,
            \"overwrite\": true
        }" \
        "http://$MONITORING_IP:3000/api/dashboards/db"
    
    echo "✅ Grafana dashboard imported"
}

get_jenkins_password() {
    print_step "Retrieving Jenkins initial password..."
    
    JENKINS_PASSWORD=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$JENKINS_IP" \
        "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'not-ready'")
    
    if [ "$JENKINS_PASSWORD" = "not-ready" ]; then
        print_warning "Jenkins not fully initialized yet. Password will be available soon."
    else
        echo "✅ Jenkins password retrieved"
    fi
}

print_summary() {
    print_step "Deployment Summary"
    
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              Deployment Completed Successfully!               ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}🔗 Service URLs:${NC}"
    echo -e "   Jenkins:     http://$JENKINS_IP:8080"
    echo -e "   Prometheus:  http://$MONITORING_IP:9090"
    echo -e "   Grafana:     http://$MONITORING_IP:3000"
    echo -e "   Jaeger:      http://$MONITORING_IP:16686"
    echo ""
    
    echo -e "${BLUE}🔐 Credentials:${NC}"
    echo -e "   Jenkins:"
    echo -e "     Username: admin"
    echo -e "     Password: $JENKINS_PASSWORD"
    echo ""
    echo -e "   Grafana:"
    echo -e "     Username: admin"
    echo -e "     Password: admin (change on first login)"
    echo ""
    
    echo -e "${BLUE}🔑 SSH Access:${NC}"
    echo -e "   Jenkins:    ssh -i $KEY_FILE ubuntu@$JENKINS_IP"
    echo -e "   Monitoring: ssh -i $KEY_FILE ubuntu@$MONITORING_IP"
    echo ""
    
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo -e "   1. Access Jenkins: http://$JENKINS_IP:8080"
    echo -e "   2. Complete Jenkins setup wizard"
    echo -e "   3. Configure OpenTelemetry plugin (see configs/jenkins/jenkins-otel-config.md)"
    echo -e "   4. Create pipelines from pipelines/ directory"
    echo -e "   5. Run failure drill pipeline"
    echo -e "   6. Complete the Battle Log"
    echo ""
    
    echo -e "${BLUE}📊 Prometheus Metrics Endpoint:${NC}"
    echo -e "   http://$JENKINS_IP:8080/prometheus"
    echo ""
    
    echo -e "${GREEN}✅ All services are ready!${NC}\n"
    
    # Save to file
    cat > "$PROJECT_ROOT/deployment-info.txt" << EOL
Jenkins Observability Challenge - Deployment Information
=========================================================

Deployed: $(date)

Service URLs:
  Jenkins:     http://$JENKINS_IP:8080
  Prometheus:  http://$MONITORING_IP:9090
  Grafana:     http://$MONITORING_IP:3000
  Jaeger:      http://$MONITORING_IP:16686

Credentials:
  Jenkins:
    Username: admin
    Password: $JENKINS_PASSWORD
  
  Grafana:
    Username: admin
    Password: admin

SSH Access:
  Jenkins:    ssh -i $KEY_FILE ubuntu@$JENKINS_IP
  Monitoring: ssh -i $KEY_FILE ubuntu@$MONITORING_IP

Private IPs:
  Jenkins:    $JENKINS_PRIVATE_IP
  Monitoring: (check AWS console)

SSH Key: $KEY_FILE
EOL
    
    echo -e "${GREEN}📄 Deployment info saved to: $PROJECT_ROOT/deployment-info.txt${NC}"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header
    
    check_prerequisites
    create_ssh_key
    deploy_infrastructure
    wait_for_instances
    configure_prometheus
    configure_otel_collector
    import_grafana_dashboard
    get_jenkins_password
    print_summary
    
    echo -e "\n${GREEN}🎉 Deployment complete! Enjoy your observability challenge!${NC}\n"
}

# Run main function
main "$@"

