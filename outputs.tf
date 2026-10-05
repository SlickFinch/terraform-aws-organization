output "organization_id" {
  description = "ID of the Organization."
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "ARN of the Organization."
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "ID of the Organization root."
  value       = local.root_id
}

output "management_account_id" {
  description = "ID of the management account."
  value       = aws_organizations_organization.this.master_account_id
}

output "enabled_policy_types" {
  description = "Policy types enabled on the root."
  value       = local.enabled_policy_types
}

output "organizational_units" {
  description = "OUs keyed by OU key: id, arn, name and parent_id."
  value = {
    for k, ou in local.organizational_units : k => {
      id        = ou.id
      arn       = ou.arn
      name      = ou.name
      parent_id = ou.parent_id
    }
  }
}

output "organizational_unit_ids" {
  description = "OU IDs keyed by OU key."
  value       = { for k, ou in local.organizational_units : k => ou.id }
}

output "accounts" {
  description = "Accounts keyed by account key: id, arn, name, email, parent_id and state."
  value = {
    for k, a in aws_organizations_account.this : k => {
      id        = a.id
      arn       = a.arn
      name      = a.name
      email     = a.email
      parent_id = a.parent_id
      state     = a.state
    }
  }
}

output "account_ids" {
  description = "Account IDs keyed by account key."
  value       = { for k, a in aws_organizations_account.this : k => a.id }
}

output "policies" {
  description = "Policies keyed by name: id, arn and type."
  value       = { for k, p in aws_organizations_policy.this : k => { id = p.id, arn = p.arn, type = p.type } }
}
