locals {
  account_emails = {
    for k, a in var.accounts : k => (
      a.email != null ? a.email :
      var.account_email_format != null ? format(var.account_email_format, coalesce(a.email_alias, k)) :
      null
    )
  }
}

resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name                       = coalesce(each.value.name, each.key)
  email                      = local.account_emails[each.key]
  parent_id                  = each.value.parent != null ? local.organizational_units[each.value.parent].id : coalesce(each.value.parent_id, local.root_id)
  close_on_deletion          = each.value.close_on_deletion
  iam_user_access_to_billing = each.value.iam_user_access_to_billing
  role_name                  = each.value.role_name
  tags                       = merge(var.tags, each.value.tags)

  lifecycle {
    # Removing an account from var.accounts would remove it from the
    # Organization or close it. Do that on purpose: set close_on_deletion,
    # then remove the account from state and close it, or drop this guard in
    # a fork.
    prevent_destroy = true

    # AWS can't read these back, and changing them would replace the account.
    ignore_changes = [iam_user_access_to_billing, role_name]

    precondition {
      condition     = local.account_emails[each.key] != null
      error_message = "Account ${each.key} has no email. Set email on the account, or set account_email_format."
    }
  }
}
