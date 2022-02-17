# Underlying infrastructure settings

variable "zone" {
  description = "Target zone of the infrastructure (e.g. 'ch-gva-2', 'ch-dk-2', 'de-fra-1', 'de-muc-1', etc.)."
  type        = string
}

variable "template_id" {
  description = "OS template id to use. Reference implementation is built using the `packer-exoscale` repository."
  type        = string
}

variable "instance_type" {
  description = "Service offering of member instances. `standard.tiny` should be sufficient for use with a small Kubernetes cluster."
  type        = string
}

variable "disk_size" {
  description = "Size of the root partition in GB. `10` should be sufficient for use with a bunch of small Kubernetes cluster."
  type        = number
}

variable "security_group_rules" {
  description = "A list of security groups to add. Clients of the cluster can be authorized using this variable."
  type = map(object({
    protocol = string
    type     = string
    port     = number
    source   = string
  }))
  default = {}
}

variable "ipv4" {
  description = "If IPv4 must be enabled on member instances (can only be 'true' for now)."
  type        = bool
  default     = true
}

variable "ipv6" {
  description = "If IPv6 must be enabled on member instances."
  type        = bool
  default     = false
}

variable "ssh_key" {
  description = "Authorized SSH key."
  type        = string
}

# Cluster settings

variable "cluster_name" {
  description = "The name of the cluster."
  type        = string
}

variable "hostnames" {
  description = "The list of hostnames that are cluster members. This variable also define how many members are set."
  type        = set(string)
}

variable "preferred_link" {
  description = "The preferred link for communication inside of the cluster and with clients (valid values: 'public-ipv6', 'public-ipv4')."
  type        = string
  default     = "public-ipv6"

  validation {
    condition     = contains(["public-ipv4", "public-ipv6"], var.preferred_link)
    error_message = "The `preferred_link` value must be either 'public-ipv6' or 'public-ipv4'."
  }
}

# Instance settings

variable "connection" {
  description = "Connection settings for the initial setup of the cluster."
  type = object({
    user        = string
    private_key = string
  })
}

variable "pki" {
  description = "How TLS is handled (valid `.mode` values: 'disabled', 'terraform')."
  type = object({
    mode = string
  })

  default = {
    mode = "terraform"
  }

  validation {
    condition     = contains(["disabled", "terraform"], var.pki.mode)
    error_message = "The `pki.mode` value must be either 'disabled' or 'terraform'."
  }
}
