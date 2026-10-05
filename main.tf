locals {
  enabled_policy_types = sort(distinct(concat(
    var.enabled_policy_types,
    [for p in values(var.policies) : p.type],
  )))

  root_id = aws_organizations_organization.this.roots[0].id
}

# Destroying an Organization fails while it has member accounts, and losing it
# is never what anyone wants. Remove it from state on purpose if you must.
resource "aws_organizations_organization" "this" {
  feature_set          = var.feature_set
  enabled_policy_types = local.enabled_policy_types

  lifecycle {
    prevent_destroy = true

    # Trusted access lives in aws_organizations_aws_service_access, one
    # resource per service, so services that enable their own access don't
    # cause drift here.
    ignore_changes = [aws_service_access_principals]
  }
}

resource "aws_organizations_aws_service_access" "this" {
  for_each = toset(var.aws_service_access_principals)

  service_principal = each.key

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_resource_policy" "this" {
  count = var.resource_policy == null ? 0 : 1

  content = var.resource_policy
  tags    = var.tags

  depends_on = [aws_organizations_organization.this]
}
