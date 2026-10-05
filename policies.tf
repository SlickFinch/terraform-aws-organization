locals {
  # Attachments are keyed by "<policy>:<target>" as the caller wrote them, not
  # by IDs, so new OUs and accounts plan in one pass.
  policy_attachments = merge([
    for name, p in var.policies : {
      for target in p.targets : "${name}:${target}" => {
        policy       = name
        target       = target
        skip_destroy = p.skip_destroy
      }
    }
  ]...)
}

resource "aws_organizations_policy" "this" {
  for_each = var.policies

  name         = each.key
  type         = each.value.type
  description  = each.value.description
  content      = each.value.content
  skip_destroy = each.value.skip_destroy
  tags         = merge(var.tags, each.value.tags)

  # The root must have the policy type enabled first.
  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = local.policy_attachments

  policy_id = aws_organizations_policy.this[each.value.policy].id
  target_id = (
    each.value.target == "root" ? local.root_id :
    contains(keys(local.organizational_units), each.value.target) ? local.organizational_units[each.value.target].id :
    contains(keys(aws_organizations_account.this), each.value.target) ? aws_organizations_account.this[each.value.target].id :
    each.value.target
  )
  skip_destroy = each.value.skip_destroy
}
