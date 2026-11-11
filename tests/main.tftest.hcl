# Runs without AWS credentials: `tofu test` (or `terraform test`).
# Every run is plan-only: accounts and the Organization have prevent_destroy,
# so the test cleanup could not destroy applied mock resources.

mock_provider "aws" {
  override_resource {
    target = aws_organizations_organization.this
    values = {
      id                = "o-exampleorg1"
      master_account_id = "111111111111"
      roots = [{
        id           = "r-ab12"
        arn          = "arn:aws:organizations::111111111111:root/o-exampleorg1/r-ab12"
        name         = "Root"
        policy_types = []
      }]
    }
  }

  # Random mock IDs fail the provider's ID checks. One ID per OU level keeps
  # the parent assertions meaningful.
  override_resource {
    target = aws_organizations_organizational_unit.level_1
    values = { id = "ou-ab12-11111111", arn = "arn:aws:organizations::111111111111:ou/o-exampleorg1/ou-ab12-11111111" }
  }
  override_resource {
    target = aws_organizations_organizational_unit.level_2
    values = { id = "ou-ab12-22222222", arn = "arn:aws:organizations::111111111111:ou/o-exampleorg1/ou-ab12-22222222" }
  }
  override_resource {
    target = aws_organizations_organizational_unit.level_3
    values = { id = "ou-ab12-33333333", arn = "arn:aws:organizations::111111111111:ou/o-exampleorg1/ou-ab12-33333333" }
  }
  override_resource {
    target = aws_organizations_account.this
    values = { id = "222222222222", arn = "arn:aws:organizations::111111111111:account/o-exampleorg1/222222222222", state = "ACTIVE" }
  }
  override_resource {
    target = aws_organizations_policy.this
    values = { id = "p-abcd1234" }
  }
  # The nested IAM role modules need valid policy JSON.
  override_data {
    target = module.control_tower_admin_role[0].data.aws_iam_policy_document.this
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  override_data {
    target = module.control_tower_admin_role[0].data.aws_iam_policy_document.inline
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  override_data {
    target = module.control_tower_cloudtrail_role[0].data.aws_iam_policy_document.this
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  override_data {
    target = module.control_tower_cloudtrail_role[0].data.aws_iam_policy_document.inline
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  override_data {
    target = module.control_tower_stackset_role[0].data.aws_iam_policy_document.this
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  override_data {
    target = module.control_tower_stackset_role[0].data.aws_iam_policy_document.inline
    values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  account_email_format = "aws+%s@example.com"

  organizational_units = {
    Security       = {}
    Infrastructure = {}
    Workloads      = {}
    Prod           = { parent = "Workloads" }
    NonProd        = { parent = "Workloads" }
    Sandbox        = { parent = "NonProd", name = "Sandbox OU" }
  }

  accounts = {
    log-archive = { parent = "Security" }
    audit       = { parent = "Security", email_alias = "security-audit" }
    prod        = { parent = "Prod", email = "owner@example.com" }
    legacy      = { parent_id = "ou-ab12-managedelsewhere" }
    stray       = {}
  }

  policies = {
    guardrails = {
      content = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"organizations:LeaveOrganization\",\"Resource\":\"*\"}]}"
      targets = ["Security", "Workloads", "prod", "r-ab12"]
    }
    data-perimeter = {
      type    = "RESOURCE_CONTROL_POLICY"
      content = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      targets = ["root"]
    }
  }

  enabled_policy_types          = ["TAG_POLICY"]
  aws_service_access_principals = ["sso.amazonaws.com", "account.amazonaws.com"]
  delegated_administrators      = { "guardduty.amazonaws.com" = "audit" }
}

run "builds_nested_ous_and_accounts" {
  command = plan

  assert {
    condition     = local.ou_depth == { Security = 1, Infrastructure = 1, Workloads = 1, Prod = 2, NonProd = 2, Sandbox = 3 }
    error_message = "OU depths are wrong: ${jsonencode(local.ou_depth)}"
  }

  assert {
    condition     = aws_organizations_organizational_unit.level_3["Sandbox"].name == "Sandbox OU"
    error_message = "OU name override was ignored."
  }

  assert {
    condition     = aws_organizations_organizational_unit.level_3["Sandbox"].parent_id == aws_organizations_organizational_unit.level_2["NonProd"].id
    error_message = "Sandbox isn't under NonProd."
  }

  assert {
    condition     = aws_organizations_organizational_unit.level_1["Security"].parent_id == "r-ab12"
    error_message = "Top-level OUs must sit under the root."
  }

  assert {
    condition = (
      aws_organizations_account.this["log-archive"].email == "aws+log-archive@example.com" &&
      aws_organizations_account.this["audit"].email == "aws+security-audit@example.com" &&
      aws_organizations_account.this["prod"].email == "owner@example.com"
    )
    error_message = "Account emails don't follow account_email_format, email_alias and email."
  }

  assert {
    condition = (
      aws_organizations_account.this["prod"].parent_id == aws_organizations_organizational_unit.level_2["Prod"].id &&
      aws_organizations_account.this["legacy"].parent_id == "ou-ab12-managedelsewhere" &&
      aws_organizations_account.this["stray"].parent_id == "r-ab12"
    )
    error_message = "Account parents resolve wrongly."
  }

  assert {
    condition     = toset(keys(aws_organizations_policy_attachment.this)) == toset(["guardrails:Security", "guardrails:Workloads", "guardrails:prod", "guardrails:r-ab12", "data-perimeter:root"])
    error_message = "Policy attachments aren't keyed by policy and target."
  }

  assert {
    condition = (
      aws_organizations_policy_attachment.this["guardrails:prod"].target_id == aws_organizations_account.this["prod"].id &&
      aws_organizations_policy_attachment.this["data-perimeter:root"].target_id == "r-ab12" &&
      aws_organizations_policy_attachment.this["guardrails:r-ab12"].target_id == "r-ab12"
    )
    error_message = "Policy attachment targets resolve wrongly."
  }

  assert {
    condition     = aws_organizations_organization.this.enabled_policy_types == toset(["RESOURCE_CONTROL_POLICY", "SERVICE_CONTROL_POLICY", "TAG_POLICY"])
    error_message = "Policy types used by policies must be enabled on the root."
  }

  assert {
    condition     = aws_organizations_delegated_administrator.this["guardduty.amazonaws.com"].account_id == aws_organizations_account.this["audit"].id
    error_message = "Delegated administrator account key didn't resolve."
  }
}

run "rejects_unknown_ou_parent" {
  command = plan

  variables {
    organizational_units = {
      Prod = { parent = "Missing" }
    }
    accounts                 = {}
    policies                 = {}
    delegated_administrators = {}
  }

  expect_failures = [var.organizational_units]
}

run "rejects_ou_loop" {
  command = plan

  variables {
    organizational_units = {
      A = { parent = "B" }
      B = { parent = "A" }
    }
    accounts                 = {}
    policies                 = {}
    delegated_administrators = {}
  }

  expect_failures = [terraform_data.ou_depth_check]
}

run "requires_an_email" {
  command = plan

  variables {
    account_email_format     = null
    accounts                 = { orphan = {} }
    policies                 = {}
    organizational_units     = {}
    delegated_administrators = {}
  }

  expect_failures = [aws_organizations_account.this]
}

run "rejects_unknown_delegated_administrator" {
  command = plan

  variables {
    delegated_administrators = { "guardduty.amazonaws.com" = "nobody" }
  }

  expect_failures = [aws_organizations_delegated_administrator.this]
}

run "control_tower_and_ram_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_controltower_landing_zone.this) == 0 && length(module.control_tower_admin_role) == 0
    error_message = "Control Tower must be off when control_tower is null."
  }

  assert {
    condition     = length(aws_ram_sharing_with_organization.this) == 0
    error_message = "RAM sharing must be off by default."
  }
}

run "ram_sharing_on" {
  command = plan

  variables {
    enable_ram_sharing_with_organization = true
  }

  assert {
    condition     = length(aws_ram_sharing_with_organization.this) == 1
    error_message = "enable_ram_sharing_with_organization must turn on RAM sharing."
  }
}

run "control_tower_on" {
  command = plan

  variables {
    control_tower = {
      version = "4.0"
      manifest = {
        governedRegions    = ["us-west-2"]
        centralizedLogging = { enabled = true, accountId = "222222222222" }
        config             = { enabled = true, accountId = "222222222222" }
      }
      baseline_arn         = "arn:aws:controltower:us-west-2::baseline/17BSJV3IGJ2QSGA2"
      registered_ous       = ["Infrastructure", "Workloads"]
      registered_child_ous = ["Prod", "NonProd"]
    }
  }

  assert {
    condition     = length(aws_controltower_landing_zone.this) == 1
    error_message = "control_tower must create the landing zone."
  }

  assert {
    condition     = jsondecode(aws_controltower_landing_zone.this[0].manifest_json).governedRegions == ["us-west-2"]
    error_message = "The landing zone must use the manifest."
  }

  assert {
    condition     = aws_controltower_landing_zone.this[0].remediation_types == toset(["INHERITANCE_DRIFT"])
    error_message = "remediation_types must default to INHERITANCE_DRIFT."
  }

  assert {
    condition     = toset(keys(aws_controltower_baseline.top_level_ous)) == toset(["Infrastructure", "Workloads"]) && toset(keys(aws_controltower_baseline.child_ous)) == toset(["Prod", "NonProd"])
    error_message = "Every registered OU must get a baseline."
  }

  assert {
    condition     = length(module.control_tower_admin_role) == 1 && length(module.control_tower_cloudtrail_role) == 1 && length(module.control_tower_stackset_role) == 1
    error_message = "control_tower must create the three service roles."
  }
}

run "control_tower_without_service_roles" {
  command = plan

  variables {
    control_tower = {
      version              = "4.0"
      manifest             = { governedRegions = ["us-west-2"] }
      baseline_arn         = "arn:aws:controltower:us-west-2::baseline/17BSJV3IGJ2QSGA2"
      create_service_roles = false
    }
  }

  assert {
    condition     = length(module.control_tower_admin_role) == 0
    error_message = "create_service_roles = false must skip the service roles."
  }
}

run "rejects_log_account_outside_security_ou" {
  command = plan

  variables {
    control_tower = {
      version = "4.0"
      manifest = {
        centralizedLogging = { enabled = true, accountId = "999999999999" }
      }
      baseline_arn = "arn:aws:controltower:us-west-2::baseline/17BSJV3IGJ2QSGA2"
    }
  }

  expect_failures = [aws_controltower_landing_zone.this]
}

run "rejects_unknown_registered_ou" {
  command = plan

  variables {
    control_tower = {
      version        = "4.0"
      manifest       = {}
      baseline_arn   = "arn:aws:controltower:us-west-2::baseline/17BSJV3IGJ2QSGA2"
      registered_ous = ["Nowhere"]
    }
  }

  expect_failures = [var.control_tower]
}
