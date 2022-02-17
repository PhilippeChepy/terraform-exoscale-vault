# Base resources from Exoscale

resource "exoscale_anti_affinity_group" "cluster" {
  name        = var.cluster_name
  description = "Hashicorp Vault (${var.cluster_name})"
}

resource "exoscale_security_group" "cluster" {
  name = var.cluster_name
}

resource "exoscale_security_group_rule" "cluster_rule" {
  for_each = {
    "sg-tcp-8200" = { type = "INGRESS", protocol = "TCP", port = "8200" }
    "sg-tcp-8201" = { type = "INGRESS", protocol = "TCP", port = "8201" }
  }

  security_group_id      = exoscale_security_group.cluster.id
  protocol               = each.value["protocol"]
  type                   = each.value["type"]
  start_port             = each.value["port"]
  end_port               = each.value["port"]
  user_security_group_id = exoscale_security_group.cluster.id
}

resource "exoscale_security_group_rule" "cluster_client_rule" {
  for_each = var.security_group_rules

  security_group_id      = exoscale_security_group.cluster.id
  protocol               = each.value["protocol"]
  type                   = each.value["type"]
  start_port             = each.value["port"]
  end_port               = each.value["port"]
  user_security_group_id = each.value["source"]
}

resource "exoscale_compute_instance" "peer" {
  for_each = var.hostnames

  name                    = each.value
  template_id             = var.template_id
  type                    = var.instance_type
  disk_size               = var.disk_size
  zone                    = var.zone
  anti_affinity_group_ids = [exoscale_anti_affinity_group.cluster.id]
  security_group_ids      = [exoscale_security_group.cluster.id]
  ipv6                    = var.ipv6
  ssh_key                 = var.ssh_key
}

locals {
  public_ipv6 = var.preferred_link == "public-ipv6" && var.ipv6

  # For cluster configuration
  public_ipv4_cluster_address = { for peer, specs in exoscale_compute_instance.peer : peer => "${specs.public_ip_address}:8201" }
  public_ipv6_cluster_address = { for peer, specs in exoscale_compute_instance.peer : peer => "[${specs.ipv6_address}]:8201" }
  vault_cluster_address       = local.public_ipv6 ? local.public_ipv6_cluster_address : local.public_ipv4_cluster_address
  public_ipv4_api_address     = { for peer, specs in exoscale_compute_instance.peer : peer => "${specs.public_ip_address}:8200" }
  public_ipv6_api_address     = { for peer, specs in exoscale_compute_instance.peer : peer => "[${specs.ipv6_address}]:8200" }
  vault_api_address           = local.public_ipv6 ? local.public_ipv6_api_address : local.public_ipv4_api_address
  vault_api_addresses         = values(local.vault_api_address)

  # IP SANs to be included in certificates
  tls_public_ipv4 = { for peer, specs in exoscale_compute_instance.peer : peer => (var.ipv4 ? [specs.public_ip_address] : []) }
  tls_public_ipv6 = { for peer, specs in exoscale_compute_instance.peer : peer => (var.ipv6 ? [specs.ipv6_address] : []) }
}

# TLS mode : terraform

module "ca_certificates" {
  source   = "git@github.com:PhilippeChepy/terraform-tls-root-ca.git"
  for_each = var.pki.mode == "terraform" ? toset(["server"]) : []

  common_name           = "Vault ${each.value} CA"
  validity_period_hours = 87660
}

module "server_certificate" {
  source   = "git@github.com:PhilippeChepy/terraform-tls-certificate.git"
  for_each = var.pki.mode == "terraform" ? exoscale_compute_instance.peer : {}

  signing_key_pem  = module.ca_certificates["server"].private_key_pem
  signing_cert_pem = module.ca_certificates["server"].certificate_pem

  common_name = each.key
  dns_sans    = [each.key]
  ip_sans     = concat(local.tls_public_ipv4[each.key], local.tls_public_ipv6[each.key])

  server_auth = true
  client_auth = true

  validity_period_hours = 87660
}

module "peer_certificate" {
  source   = "git@github.com:PhilippeChepy/terraform-tls-certificate.git"
  for_each = var.pki.mode == "terraform" ? exoscale_compute_instance.peer : {}

  signing_key_pem  = module.ca_certificates["server"].private_key_pem
  signing_cert_pem = module.ca_certificates["server"].certificate_pem

  common_name = each.value.name
  dns_sans    = [each.value.name]
  ip_sans     = concat(local.tls_public_ipv4[each.key], local.tls_public_ipv6[each.key])

  server_auth = true
  client_auth = true

  validity_period_hours = 87660
}

# Service bootstrapping

module "vault_service" {
  source   = "git@github.com:PhilippeChepy/terraform-initial-provisioning.git"
  for_each = exoscale_compute_instance.peer

  connection = merge(
    { host = each.value.public_ip_address },
    var.connection
  )

  files = merge(var.pki.mode == "terraform" ? { # Start of "terraform" pki specific stuff
    # CA and certificate/private key for communication with clients
    "/etc/vault/tls/ca.pem" = {
      content = module.ca_certificates["server"].certificate_pem
      owner   = "vault"
      group   = "vault"
      mode    = "0644"
    }
    "/etc/vault/tls/server-cert.pem" = {
      content = module.server_certificate[each.key].certificate_pem
      owner   = "vault"
      group   = "vault"
      mode    = "0644"
    }
    "/etc/vault/tls/server-cert.key" = {
      content = module.server_certificate[each.key].private_key_pem
      owner   = "vault"
      group   = "vault"
      mode    = "0600"
    }
    "/etc/vault/tls/peer-cert.pem" = {
      content = module.peer_certificate[each.key].certificate_pem
      owner   = "vault"
      group   = "vault"
      mode    = "0644"
    }
    "/etc/vault/tls/peer-cert.key" = {
      content = module.peer_certificate[each.key].private_key_pem
      owner   = "vault"
      group   = "vault"
      mode    = "0600"
    }
    } : {},
    # End of "terraform" pki
    {
      # Vault service settings (environment variables used by the vault service)
      "/etc/vault/vault.hcl" = {
        content = templatefile("${path.module}/templates/vault.hcl", {
          hostname        = each.key,
          cluster_address = local.vault_cluster_address[each.key]
          api_address     = local.vault_api_address[each.key]
          peers = setsubtract(
            local.vault_api_addresses,
            [local.vault_api_address[each.key]]
          )
        })
        owner = "vault"
        group = "vault"
        mode  = "0644"
      }
      # vault cli default settings (environment variables sourced from the .bashrc of the vault user)
      # When updated, it doesn't require a service restart but it has same preriquisites than /etc/vault/vault.hcl,
      # so provisioning will trigger for both at the same time.
      "/etc/default/vault" = {
        content = templatefile("${path.module}/templates/vault", {
          api_address = local.vault_api_address[each.key]
        })
        owner = "vault"
        group = "vault"
        mode  = "0644"
      }
  })

  post_exec = [
    "sudo systemctl enable vault",
    "sudo systemctl start vault"
  ]
}
