# Control Tower landing zone without AFT; set var.control_tower to turn it on.

locals {
  create_control_tower       = var.control_tower != null
  create_control_tower_roles = local.create_control_tower && try(var.control_tower.create_service_roles, true)

  # Accounts the manifest names for logging and Config; Control Tower needs them in the security OU.
  control_tower_account_ids = local.create_control_tower ? compact([
    try(var.control_tower.manifest.centralizedLogging.accountId, null),
    try(var.control_tower.manifest.config.accountId, null),
  ]) : []
  security_ou_account_ids = [
    for k, a in aws_organizations_account.this : a.id if local.create_control_tower && var.accounts[k].parent == try(var.control_tower.security_ou, null)
  ]
}

resource "aws_controltower_landing_zone" "this" {
  count = local.create_control_tower ? 1 : 0

  version           = var.control_tower.version
  manifest_json     = jsonencode(var.control_tower.manifest)
  remediation_types = var.control_tower.remediation_types
  tags              = length(var.tags) > 0 ? var.tags : null

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = alltrue([for id in local.control_tower_account_ids : contains(local.security_ou_account_ids, id)])
      error_message = "The manifest's log archive and audit accounts must be accounts of this module in control_tower.security_ou."
    }
  }

  depends_on = [
    aws_organizations_organization.this,
    aws_organizations_account.this,
    module.control_tower_admin_role,
    module.control_tower_cloudtrail_role,
    module.control_tower_stackset_role,
  ]
}

# Control Tower registers the security OU itself; a child OU registers only after its parent.
resource "aws_controltower_baseline" "top_level_ous" {
  for_each = local.create_control_tower ? toset(var.control_tower.registered_ous) : toset([])

  baseline_identifier = var.control_tower.baseline_arn
  baseline_version    = var.control_tower.baseline_version
  target_identifier   = local.organizational_units[each.key].arn
  tags                = length(var.tags) > 0 ? var.tags : null

  depends_on = [aws_controltower_landing_zone.this]
}

resource "aws_controltower_baseline" "child_ous" {
  for_each = local.create_control_tower ? toset(var.control_tower.registered_child_ous) : toset([])

  baseline_identifier = var.control_tower.baseline_arn
  baseline_version    = var.control_tower.baseline_version
  target_identifier   = local.organizational_units[each.key].arn
  tags                = length(var.tags) > 0 ? var.tags : null

  depends_on = [aws_controltower_baseline.top_level_ous]
}
