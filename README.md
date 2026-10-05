# terraform-aws-organization

OpenTofu and Terraform module that manages an AWS Organization: the Organization itself, nested OUs, member accounts, policies of every type, trusted service access, delegated administrators, the Organization resource policy and account alternate contacts.

It works next to AWS Control Tower without AFT. The module creates accounts and OUs, and Control Tower enrolls the accounts when you register their OU.

## Usage

Run it from the Organization management account. Pin the module to a release tag:

```hcl
module "organization" {
  source = "git::https://github.com/SlickFinch/terraform-aws-organization.git?ref=v1.0.0"

  aws_service_access_principals = ["sso.amazonaws.com"]

  organizational_units = {
    Security  = {}
    Workloads = {}
    Prod      = { parent = "Workloads" }
    NonProd   = { parent = "Workloads" }
  }

  # Plus addressing: the account key goes in place of %s.
  account_email_format = "aws+%s@example.com"

  accounts = {
    "acme-log-archive" = { parent = "Security", email_alias = "log-archive" }
    "acme-prod"        = { parent = "Prod", email_alias = "prod" }
  }

  policies = {
    "acme-guardrails" = {
      content = data.aws_iam_policy_document.guardrails.json
      targets = ["Security", "Workloads"]
    }
  }
}
```

See [examples/complete](examples/complete) for every feature.

## How it behaves

- **Stable keys.** OUs, accounts, policies and attachments use your map keys, never IDs. You can create an OU, put an account in it and attach a policy to both in one plan.
- **Nested OUs.** Set `parent` to another OU's key. AWS allows five levels. The module rejects unknown parents and loops.
- **Account emails.** Set `email` per account, or set `account_email_format` once (for example `aws+%s@example.com`). `%s` gets the account's `email_alias`, or its key.
- **Policy targets.** Each target is `"root"`, an OU key, an account key or a literal ID (`r-…`, `ou-…`, a 12-digit account ID). If a key names both an OU and an account, the OU wins.
- **Policy types.** The module enables every type that `policies` uses on the root. Add others with `enabled_policy_types`. `INSPECTOR_POLICY` and `SECURITYHUB_POLICY` also need trusted access for their service.
- **Trusted access.** Each principal in `aws_service_access_principals` is its own `aws_organizations_aws_service_access` resource. The Organization ignores `aws_service_access_principals`, so services that enable their own access, such as Control Tower, don't cause drift.
- **Delegated administrators.** Map a service principal to an account key or account ID.
- **Alternate contacts** apply to every account the module manages. They need trusted access for `account.amazonaws.com`.

## Safety

- The Organization and every account have `prevent_destroy`. Removing an account from `accounts` fails the plan. To remove or close an account, take it out of state on purpose (`tofu state rm`), then close or remove it in AWS.
- `iam_user_access_to_billing` and `role_name` apply only when an account is created. AWS can't read them back, so the module ignores later changes, and imported accounts don't show a diff.
- `close_on_deletion` defaults to `false`.

## Import an existing Organization

`import` blocks work only in the root module, so put them next to the module call:

```hcl
import {
  to = module.organization.aws_organizations_organization.this
  id = "o-abc1234567"
}

import {
  to = module.organization.aws_organizations_account.this["acme-dev"]
  id = "123456789012"
}

import {
  to = module.organization.aws_organizations_aws_service_access.this["sso.amazonaws.com"]
  id = "sso.amazonaws.com"
}
```

Import OUs at the address for their depth: `aws_organizations_organizational_unit.level_1["Security"]`, `level_2["Prod"]` and so on. Delete the import blocks after the apply.

## Testing

```bash
mise install
tofu test            # mocked provider, no AWS credentials needed
pre-commit run --all-files
```

## Versioning

Releases follow [semantic versioning](https://semver.org). Each release is a `vMAJOR.MINOR.PATCH` git tag with a GitHub release. [CHANGELOG.md](CHANGELOG.md) lists the changes in each release.

- **Patch:** bug fixes. No change to inputs, outputs or resources.
- **Minor:** new inputs or outputs with safe defaults.
- **Major:** anything that makes callers change code, raises a provider floor, or replaces resources.

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_account_alternate_contact.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_organizations_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_aws_service_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_aws_service_access) | resource |
| [aws_organizations_delegated_administrator.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_delegated_administrator) | resource |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization) | resource |
| [aws_organizations_organizational_unit.level_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.level_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.level_3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.level_4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.level_5](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_resource_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_resource_policy) | resource |
| [terraform_data.ou_depth_check](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_email_format"></a> [account\_email\_format](#input\_account\_email\_format) | format() string for account emails that aren't set explicitly, for example "aws+%s@example.com" for plus addressing. The %s gets the account's email\_alias, or its key. | `string` | `null` | no |
| <a name="input_accounts"></a> [accounts](#input\_accounts) | Member accounts keyed by account name.<br/>- email: full email address. If null, the module builds it from account\_email\_format.<br/>- email\_alias: value put into account\_email\_format. Defaults to the map key.<br/>- name: account name. Defaults to the map key.<br/>- parent: key of an OU in organizational\_units. parent\_id: an OU or root ID managed elsewhere. If both are null, the account goes under the root.<br/>- close\_on\_deletion: close the account when the resource is destroyed. Accounts also have prevent\_destroy.<br/>- iam\_user\_access\_to\_billing and role\_name only apply at creation. The module ignores later changes, so imported accounts don't show a diff. | <pre>map(object({<br/>    email                      = optional(string)<br/>    email_alias                = optional(string)<br/>    name                       = optional(string)<br/>    parent                     = optional(string)<br/>    parent_id                  = optional(string)<br/>    close_on_deletion          = optional(bool, false)<br/>    iam_user_access_to_billing = optional(string)<br/>    role_name                  = optional(string)<br/>    tags                       = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_alternate_contacts"></a> [alternate\_contacts](#input\_alternate\_contacts) | Alternate contacts (BILLING, OPERATIONS, SECURITY) set on every account this module manages. Needs trusted access for account.amazonaws.com. | <pre>map(object({<br/>    name          = string<br/>    title         = string<br/>    email_address = string<br/>    phone_number  = string<br/>  }))</pre> | `{}` | no |
| <a name="input_aws_service_access_principals"></a> [aws\_service\_access\_principals](#input\_aws\_service\_access\_principals) | Service principals to give trusted access to the Organization, for example sso.amazonaws.com. Each one is its own resource, so services that enable their own access (Control Tower, for example) don't cause drift. | `list(string)` | `[]` | no |
| <a name="input_delegated_administrators"></a> [delegated\_administrators](#input\_delegated\_administrators) | Delegated administrators as service principal => account. The account is an account key from var.accounts or a 12-digit account ID. | `map(string)` | `{}` | no |
| <a name="input_enabled_policy_types"></a> [enabled\_policy\_types](#input\_enabled\_policy\_types) | Policy types to enable on the root, in addition to the types used in var.policies. Valid values: AISERVICES\_OPT\_OUT\_POLICY, BACKUP\_POLICY, BEDROCK\_POLICY, CHATBOT\_POLICY, DECLARATIVE\_POLICY\_EC2, INSPECTOR\_POLICY, RESOURCE\_CONTROL\_POLICY, S3\_POLICY, SECURITYHUB\_POLICY, SERVICE\_CONTROL\_POLICY, TAG\_POLICY, UPGRADE\_ROLLOUT\_POLICY. | `list(string)` | `[]` | no |
| <a name="input_feature_set"></a> [feature\_set](#input\_feature\_set) | Organization feature set: ALL or CONSOLIDATED\_BILLING. Policies, delegated administrators and trusted access need ALL. | `string` | `"ALL"` | no |
| <a name="input_organizational_units"></a> [organizational\_units](#input\_organizational\_units) | OUs keyed by a stable key. parent is the key of another OU in this map, or null for the root. name defaults to the key. OUs can nest up to 5 levels deep. | <pre>map(object({<br/>    name   = optional(string)<br/>    parent = optional(string)<br/>    tags   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Organization policies keyed by policy name.<br/>- type: policy type. Defaults to SERVICE\_CONTROL\_POLICY. The module enables every type used here on the root.<br/>- targets: where to attach the policy. Each entry is "root", an OU key, an account key, or a literal root, OU or account ID.<br/>- skip\_destroy: keep the policy (and its attachments) in AWS when it leaves the configuration. | <pre>map(object({<br/>    content      = string<br/>    type         = optional(string, "SERVICE_CONTROL_POLICY")<br/>    description  = optional(string)<br/>    targets      = optional(list(string), [])<br/>    skip_destroy = optional(bool, false)<br/>    tags         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_resource_policy"></a> [resource\_policy](#input\_resource\_policy) | JSON resource policy for the Organization, which delegates Organizations read or management actions to member accounts. Null to manage none. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for every taggable resource. Per-resource tags win on conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | Account IDs keyed by account key. |
| <a name="output_accounts"></a> [accounts](#output\_accounts) | Accounts keyed by account key: id, arn, name, email, parent\_id and state. |
| <a name="output_enabled_policy_types"></a> [enabled\_policy\_types](#output\_enabled\_policy\_types) | Policy types enabled on the root. |
| <a name="output_management_account_id"></a> [management\_account\_id](#output\_management\_account\_id) | ID of the management account. |
| <a name="output_organization_arn"></a> [organization\_arn](#output\_organization\_arn) | ARN of the Organization. |
| <a name="output_organization_id"></a> [organization\_id](#output\_organization\_id) | ID of the Organization. |
| <a name="output_organizational_unit_ids"></a> [organizational\_unit\_ids](#output\_organizational\_unit\_ids) | OU IDs keyed by OU key. |
| <a name="output_organizational_units"></a> [organizational\_units](#output\_organizational\_units) | OUs keyed by OU key: id, arn, name and parent\_id. |
| <a name="output_policies"></a> [policies](#output\_policies) | Policies keyed by name: id, arn and type. |
| <a name="output_root_id"></a> [root\_id](#output\_root\_id) | ID of the Organization root. |
<!-- END_TF_DOCS -->
