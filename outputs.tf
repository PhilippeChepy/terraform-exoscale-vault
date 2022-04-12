output "url" {
  description = "The URL of the cluster, for use by clients."
  value       = "https://${exoscale_elastic_ip.endpoint.ip_address}:8200"
}

output "client_security_group_id" {
  description = "A security group id to add to cluster clients."
  value       = exoscale_security_group.clients.id
}

output "eip" {
  description = "Cluster's Elastic-IP."
  value       = exoscale_elastic_ip.endpoint.ip_address
}

output "instance_ids" {
  description = "Cluster's instance IDs"
  value       = exoscale_instance_pool.cluster.virtual_machines
}