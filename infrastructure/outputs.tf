output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "monitoring_public_ip" {
  description = "Public IP of monitoring server"
  value       = aws_instance.monitoring.public_ip
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "jaeger_url" {
  description = "Jaeger UI URL"
  value       = "http://${aws_instance.monitoring.public_ip}:16686"
}

output "jenkins_private_ip" {
  description = "Private IP of Jenkins server"
  value       = aws_instance.jenkins.private_ip
}

output "monitoring_private_ip" {
  description = "Private IP of monitoring server"
  value       = aws_instance.monitoring.private_ip
}

output "ssh_jenkins" {
  description = "SSH command for Jenkins"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.jenkins.public_ip}"
}

output "ssh_monitoring" {
  description = "SSH command for monitoring"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.monitoring.public_ip}"
}

