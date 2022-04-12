# TL;DR

This module allows one to create a Vault cluster in the [Exoscale public cloud](https://www.exoscale.com).

## Usage prerequisites

Before proceeding with the installation, you need to build the Vault template from the [Packer repository](https://github.com/PhilippeChepy/packer-exoscale).

## Implementation

This module creates:
- An anti-affinity group to ensure each cluster member goes to distinct hypervisors on the Exoscale side.
- Two security groups: one for cluster members, another one for clients to be allowed to access the cluster.
- A managed EIP as final endpoint to reach the cluster.
- An instance pool to ease templates updates (by just adding new, updated members; then removing older ones). By default, this instance pool size is 3 (allows 1 failing member).

# Post-provisioning tasks

- TLS management: Vault needs a valid TLS certificate to start its API and therefore, allows other cluster operations. It's your responsibility to build and distribute this bootstrapping certificate and private key on each instances of the cluster. Currently, we choose to implement this task through an Ansible playbook (public release coming soon).
- Cluster init and unseal: once provisioned, Vault needs to be [initialized](https://www.vaultproject.io/docs/commands/operator/init). This task should be done on only one instance. After initialization, each cluster member should be [unsealed](https://www.vaultproject.io/docs/commands/operator/unseal). This should be done manually or through automatization tools. Currently, we choose to implement this task through an Ansible playbook (public release coming soon)
- Set a PKI secret engine for vault: the (I)CA path must be `pki/platform/vault`. You can also optionally build a root CA. Currently, we choose to implement this task through the [Terraform Vault provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs).
- After previous steps are completed, you can start vault-agent (`systemctl start vault-agent`) on each instance. Vault agent  is expected to authenticate using the [Exoscale Vault authentication plugin](https://github.com/exoscale/vault-plugin-auth-exoscale). It will automatically renew Vault server certificates and reload the server service.

# Out of scope from this module

This module doesn't implement some services that are required before using it or deploying it in production:
- Automatic Backups: vault snapshots backups should be properly set.
- Monitoring: service status, raft storage state, system metrics should be properly monitored.

# Module

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_exoscale"></a> [exoscale](#requirement\_exoscale) | >=0.34.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_exoscale"></a> [exoscale](#provider\_exoscale) | >=0.34.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [exoscale_anti_affinity_group.cluster](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/anti_affinity_group) | resource |
| [exoscale_elastic_ip.endpoint](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/elastic_ip) | resource |
| [exoscale_instance_pool.cluster](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/instance_pool) | resource |
| [exoscale_security_group.clients](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/security_group) | resource |
| [exoscale_security_group.cluster](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/security_group) | resource |
| [exoscale_security_group_rule.cluster_rule](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs/resources/security_group_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_security_group_ids"></a> [admin\_security\_group\_ids](#input\_admin\_security\_group\_ids) | A list of security groups IDs authorized to access SSH | `set(string)` | `[]` | no |
| <a name="input_client_security_group_ids"></a> [client\_security\_group\_ids](#input\_client\_security\_group\_ids) | A list of security groups IDs authorized to access Vault. Clients of the cluster can be authorized using this variable. | `set(string)` | `[]` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Cluster size. Recommended values are 3 or 5 (tolerates respectively 1 or 2 failure) | `number` | `3` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Size of the root partition in GB. `10` should be sufficient for most use case. | `number` | `10` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Domain name of the cluster (for FQDN definition) | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Service offering of member instances. `standard.tiny` should be sufficient for small infrastructures. | `string` | `"standard.tiny"` | no |
| <a name="input_ipv4"></a> [ipv4](#input\_ipv4) | If IPv4 must be enabled on member instances (can only be 'true' for now). | `bool` | `true` | no |
| <a name="input_ipv6"></a> [ipv6](#input\_ipv6) | If IPv6 must be enabled on member instances. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels for cluster's instances. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The base name of cluster components. | `string` | n/a | yes |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | Authorized SSH key name. | `string` | n/a | yes |
| <a name="input_template_id"></a> [template\_id](#input\_template\_id) | OS template id to use. Reference implementation is built using the `packer-exoscale` repository. | `string` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | Target zone of the infrastructure (e.g. 'ch-gva-2', 'ch-dk-2', 'de-fra-1', 'de-muc-1', etc.). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_security_group_id"></a> [client\_security\_group\_id](#output\_client\_security\_group\_id) | A security group id to add to cluster clients. |
| <a name="output_eip"></a> [eip](#output\_eip) | Cluster's Elastic-IP. |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | Cluster's instance IDs |
| <a name="output_url"></a> [url](#output\_url) | The URL of the cluster, for use by clients. |
<!-- END_TF_DOCS -->