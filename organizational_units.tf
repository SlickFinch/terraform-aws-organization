# A resource can't reference its own instances, so each OU depth (AWS allows
# five) gets its own resource. Keys stay the caller's OU keys, so plans never
# depend on IDs that are unknown until apply.

locals {
  ou_parent_1 = { for k, ou in var.organizational_units : k => ou.parent }
  ou_parent_2 = { for k, p in local.ou_parent_1 : k => p == null ? null : local.ou_parent_1[p] }
  ou_parent_3 = { for k, p in local.ou_parent_2 : k => p == null ? null : local.ou_parent_1[p] }
  ou_parent_4 = { for k, p in local.ou_parent_3 : k => p == null ? null : local.ou_parent_1[p] }
  ou_parent_5 = { for k, p in local.ou_parent_4 : k => p == null ? null : local.ou_parent_1[p] }

  ou_depth = {
    for k in keys(var.organizational_units) : k => 1 + length(compact([
      local.ou_parent_1[k], local.ou_parent_2[k], local.ou_parent_3[k], local.ou_parent_4[k], local.ou_parent_5[k],
    ]))
  }

  ous_at_depth = {
    for d in [1, 2, 3, 4, 5] : d => { for k, ou in var.organizational_units : k => ou if local.ou_depth[k] == d }
  }

  organizational_units = merge(
    aws_organizations_organizational_unit.level_1,
    aws_organizations_organizational_unit.level_2,
    aws_organizations_organizational_unit.level_3,
    aws_organizations_organizational_unit.level_4,
    aws_organizations_organizational_unit.level_5,
  )
}

resource "terraform_data" "ou_depth_check" {
  lifecycle {
    precondition {
      condition     = alltrue([for k, d in local.ou_depth : d <= 5])
      error_message = "OUs nest at most 5 levels deep, or the parents form a loop: ${join(", ", [for k, d in local.ou_depth : k if d > 5])}."
    }
  }
}

resource "aws_organizations_organizational_unit" "level_1" {
  for_each = local.ous_at_depth[1]

  name      = coalesce(each.value.name, each.key)
  parent_id = local.root_id
  tags      = merge(var.tags, each.value.tags)
}

resource "aws_organizations_organizational_unit" "level_2" {
  for_each = local.ous_at_depth[2]

  name      = coalesce(each.value.name, each.key)
  parent_id = aws_organizations_organizational_unit.level_1[each.value.parent].id
  tags      = merge(var.tags, each.value.tags)
}

resource "aws_organizations_organizational_unit" "level_3" {
  for_each = local.ous_at_depth[3]

  name      = coalesce(each.value.name, each.key)
  parent_id = aws_organizations_organizational_unit.level_2[each.value.parent].id
  tags      = merge(var.tags, each.value.tags)
}

resource "aws_organizations_organizational_unit" "level_4" {
  for_each = local.ous_at_depth[4]

  name      = coalesce(each.value.name, each.key)
  parent_id = aws_organizations_organizational_unit.level_3[each.value.parent].id
  tags      = merge(var.tags, each.value.tags)
}

resource "aws_organizations_organizational_unit" "level_5" {
  for_each = local.ous_at_depth[5]

  name      = coalesce(each.value.name, each.key)
  parent_id = aws_organizations_organizational_unit.level_4[each.value.parent].id
  tags      = merge(var.tags, each.value.tags)
}
