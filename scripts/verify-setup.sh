#!/bin/bash

##############################################################################
# Verification Script - Check if all components are working correctly
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get IPs from deployment info or Terraform
get_ips() {
    if [ -f "../deployment-info.txt" ]; then
        JENKINS_IP=$(grep "Jenkins:" ../deployment-info.txt | grep "http://" | cut -d'/' -f3 | cut -d':' -f1)
        MONITORING_IP=$(grep "Prometheus:" ../deployment-info.txt | grep "http://" | cut -d'/' -f3 | cut -d':' -f1)
    else
        cd ../infrastructure
        JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
        MONITORING_IP=$(terraform output -raw monitoring_public_ip 2>/dev/null || echo "")
        cd -
    fi
    
    if [ -z "$JENKINS_IP" ] || [ -z "$MONITORING_IP" ]; then
        echo -e "${RED}Error: Could not determine IP addresses${NC}"
        exit 1
    fi
}

check_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Checking $name... "
    
    if curl -s --max-time 5 "$url" | grep -q "$expected"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

check_metrics() {
    echo -n "Checking Jenkins Prometheus metrics... "
    
    if curl -s --max-time 5 "http://$JENKINS_IP:8080/prometheus" | grep -q "jenkins_"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "  Make sure Jenkins Prometheus plugin is installed and configured"
        return 1
    fi
}

check_prometheus_targets() {
    echo -n "Checking Prometheus targets... "
    
    local targets=$(curl -s "http://$MONITORING_IP:9090/api/v1/targets" | jq -r '.data.activeTargets[] | select(.labels.job=="jenkins") | .health')
    
    if [ "$targets" = "up" ]; then
        echo -e "${GREEN}✅ Jenkins target is UP${NC}"
        return 0
    else
        echo -e "${RED}❌ Jenkins target is DOWN${NC}"
        echo "  Check Prometheus configuration and network connectivity"
        return 1
    fi
}

check_alerts() {
    echo -n "Checking Prometheus alerts... "
    
    local alerts=$(curl -s "http://$MONITORING_IP:9090/api/v1/rules" | jq -r '.data.groups[].rules[] | select(.type=="alerting") | .name')
    local count=$(echo "$alerts" | wc -l)
    
    if [ $count -ge 4 ]; then
        echo -e "${GREEN}✅ $count alerts configured${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Only $count alerts found (expected 4+)${NC}"
        return 1
    fi
}

check_grafana_datasource() {
    echo -n "Checking Grafana Prometheus datasource... "
    
    local ds=$(curl -s -u admin:admin "http://$MONITORING_IP:3000/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .name')
    
    if [ -n "$ds" ]; then
        echo -e "${GREEN}✅ Datasource '$ds' configured${NC}"
        return 0
    else
        echo -e "${RED}❌ No Prometheus datasource found${NC}"
        return 1
    fi
}

check_grafana_dashboard() {
    echo -n "Checking Grafana Jenkins dashboard... "
    
    local dashboard=$(curl -s -u admin:admin "http://$MONITORING_IP:3000/api/search?query=jenkins" | jq -r '.[0].title')
    
    if [ -n "$dashboard" ] && [ "$dashboard" != "null" ]; then
        echo -e "${GREEN}✅ Dashboard found: $dashboard${NC}"
        return 0
    else
        echo -e "${RED}❌ Jenkins dashboard not found${NC}"
        return 1
    fi
}

print_header() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}║           Jenkins Observability - Setup Verification          ║${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
}

main() {
    print_header
    
    echo "Getting IP addresses..."
    get_ips
    
    echo -e "\nJenkins IP:    $JENKINS_IP"
    echo -e "Monitoring IP: $MONITORING_IP\n"
    
    echo -e "${BLUE}=== Service Health Checks ===${NC}\n"
    
    local failed=0
    
    check_service "Jenkins" "http://$JENKINS_IP:8080" "Jenkins" || ((failed++))
    check_service "Prometheus" "http://$MONITORING_IP:9090" "Prometheus" || ((failed++))
    check_service "Grafana" "http://$MONITORING_IP:3000" "Grafana" || ((failed++))
    check_service "Jaeger" "http://$MONITORING_IP:16686" "Jaeger" || ((failed++))
    
    echo -e "\n${BLUE}=== Metrics & Monitoring ===${NC}\n"
    
    check_metrics || ((failed++))
    check_prometheus_targets || ((failed++))
    check_alerts || ((failed++))
    
    echo -e "\n${BLUE}=== Grafana Configuration ===${NC}\n"
    
    check_grafana_datasource || ((failed++))
    check_grafana_dashboard || ((failed++))
    
    echo -e "\n${BLUE}=== Summary ===${NC}\n"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ All checks passed! Your observability stack is ready.${NC}\n"
        echo -e "Next steps:"
        echo -e "  1. Create Jenkins pipelines"
        echo -e "  2. Run the failure drill"
        echo -e "  3. Complete your battle log\n"
        return 0
    else
        echo -e "${RED}❌ $failed check(s) failed. Please review and fix the issues.${NC}\n"
        echo -e "Check the logs:"
        echo -e "  Jenkins:    ssh ubuntu@$JENKINS_IP 'journalctl -u jenkins -n 50'"
        echo -e "  Prometheus: ssh ubuntu@$MONITORING_IP 'journalctl -u prometheus -n 50'"
        echo -e "  Grafana:    ssh ubuntu@$MONITORING_IP 'journalctl -u grafana-server -n 50'\n"
        return 1
    fi
}

main "$@"

