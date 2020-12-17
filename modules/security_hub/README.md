# AWS Security Hub

Terraform module to setup and manage AWS Security Hub.

<!--- BEGIN_TF_DOCS --->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account\_id | AWS Account ID | `string` | n/a | yes |
| sns\_endpoint | Endpoint for SNS topic subscription | `string` | n/a | yes |
| sns\_endpoint\_protocol | Endpoint protocol for SNS topic subscription | `string` | n/a | yes |
| member\_accounts | A map of accounts that should be added as SecurityHub Member Accounts (format: account\_id = email) | `map(string)` | `{}` | no |
| product\_arns | A list of the ARNs of the products you want to import into Security Hub | `list(string)` | `[]` | no |
| region | The name of the AWS region where SecurityHub will be enabled | `string` | `"eu-west-1"` | no |
| sns\_security\_topic\_subscription | Enable SNS aggregated security topic subscription | `bool` | `false` | no |

## Outputs

No output.

<!--- END_TF_DOCS --->
