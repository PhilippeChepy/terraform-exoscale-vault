cluster_name = "vault"
max_lease_ttl = "768h"
default_lease_ttl = "768h"

cluster_addr = "https://${ cluster_address }"
api_addr = "https://${ api_address }"

plugin_directory = "/usr/local/lib/vault/plugins"

listener "tcp" {
  address = "${ api_address }"
  cluster_address = "${ cluster_address }"
  tls_cert_file = "/etc/vault/tls/server-cert.pem"
  tls_key_file = "/etc/vault/tls/server-cert.key"
  tls_client_ca_file="/etc/vault/tls/ca.pem"
  tls_min_version  = "tls13"
  tls_require_and_verify_client_cert = true
  tls_disable = false
}

storage "raft" {
  path = "/var/lib/vault"
  node_id = "${ hostname }"
  %{~ for peer_api_address in peers ~}
  retry_join {
    leader_api_addr = "https://${ peer_api_address }"
    leader_ca_cert_file = "/etc/vault/tls/ca.pem"
    leader_client_cert_file = "/etc/vault/tls/peer-cert.pem"
    leader_client_key_file = "/etc/vault/tls/peer-cert.key"
  }
  %{~ endfor }
}

disable_mlock = true

ui = true
