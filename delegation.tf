resource "aws_organizations_delegated_administrator" "this" {
  for_each = var.delegated_administrators

  service_principal = each.key
  account_id        = contains(keys(var.accounts), each.value) ? aws_organizations_account.this[each.value].id : each.value

  # Most services need trusted access before they accept a delegated administrator.
  depends_on = [aws_organizations_aws_service_access.this]

  lifecycle {
    precondition {
      condition     = contains(keys(var.accounts), each.value) || can(regex("^\\d{12}$", each.value))
      error_message = "Delegated administrator for ${each.key} must be an account key from var.accounts or a 12-digit account ID, not \"${each.value}\"."
    }
  }
}

locals {
  alternate_contacts = merge([
    for account in keys(var.accounts) : {
      for type, c in var.alternate_contacts : "${account}:${type}" => merge(c, { account = account, type = type })
    }
  ]...)
}

resource "aws_account_alternate_contact" "this" {
  for_each = local.alternate_contacts

  account_id             = aws_organizations_account.this[each.value.account].id
  alternate_contact_type = each.value.type
  name                   = each.value.name
  title                  = each.value.title
  email_address          = each.value.email_address
  phone_number           = each.value.phone_number

  depends_on = [aws_organizations_aws_service_access.this]
}
