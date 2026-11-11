# Changelog

## v1.1.0

- Add `enable_ram_sharing_with_organization` (default `false`).
- Add `control_tower` (default `null`): a Control Tower landing zone without AFT, its three service roles (from `terraform-aws-modules/iam` `iam-role` 6.8), and baselines for registered OUs and child OUs. The landing zone has `prevent_destroy`, and the plan fails unless the manifest's log archive and audit accounts are in `security_ou`.
- New outputs `control_tower_landing_zone_arn` and `control_tower_latest_available_version`.

## v1.0.0

- First release. Manages an AWS Organization, nested OUs (up to 5 levels), member accounts, policies of every type, policy attachments, trusted service access, delegated administrators, the Organization resource policy and account alternate contacts.
- Needs AWS provider 6.39.0 or later, for `aws_organizations_aws_service_access`.
