# complete

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.39.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.39.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_organization"></a> [organization](#module\_organization) | ../.. | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy_document.guardrails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | Account IDs keyed by account key. |
<!-- END_TF_DOCS -->
