output "control_plane_public_ip" {
  description = "Public IP of the Kubernetes Control Plane node"
  value       = aws_instance.k8s_cp.public_ip
}

output "worker_node1_public_ip" {
  description = "Public IP of Worker Node 1"
  value       = aws_instance.node1.public_ip
}

output "worker_node2_public_ip" {
  description = "Public IP of Worker Node 2"
  value       = aws_instance.node2.public_ip
}
