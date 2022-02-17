output "instance_urls" {
  description = "A list of URLs to the cluster members. For use by cluster client."
  value = [
    for peer, specs in exoscale_compute_instance.peer : local.public_ipv6 ? "https://[${specs.ipv6_address}]:8200" : "https://${peer.ip_address}:8200"
  ]
}

output "security_group" {
  description = "The cluster internal security group ID."
  value       = exoscale_security_group.cluster.id
}

output "ca_private_key_pem" {
  description = "The private key of the server TLS certificate."
  value       = var.pki.mode == "terraform" ? module.ca_certificates["server"].private_key_pem : ""
}

output "ca_certificate_pem" {
  description = "The TLS certificate of the server."
  value       = var.pki.mode == "terraform" ? module.ca_certificates["server"].certificate_pem : ""
}