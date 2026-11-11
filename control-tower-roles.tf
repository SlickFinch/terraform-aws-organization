# Service roles the Control Tower API needs before CreateLandingZone; AWS fixes the names and path (docs: lz-api-prereques.html).

module "control_tower_admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.8"
  count   = local.create_control_tower_roles ? 1 : 0

  name            = "AWSControlTowerAdmin"
  use_name_prefix = false
  path            = "/service-role/"
  description     = "Lets Control Tower manage the landing zone."

  trust_policy_permissions = {
    ControlTower = {
      actions    = ["sts:AssumeRole"]
      principals = [{ type = "Service", identifiers = ["controltower.amazonaws.com"] }]
    }
  }

  policies = {
    AWSControlTowerServiceRolePolicy = "arn:aws:iam::aws:policy/service-role/AWSControlTowerServiceRolePolicy"
  }

  create_inline_policy = true
  inline_policy_permissions = {
    DescribeAvailabilityZones = {
      actions   = ["ec2:DescribeAvailabilityZones"]
      resources = ["*"]
    }
  }

  tags = var.tags
}

module "control_tower_cloudtrail_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.8"
  count   = local.create_control_tower_roles ? 1 : 0

  name            = "AWSControlTowerCloudTrailRole"
  use_name_prefix = false
  path            = "/service-role/"
  description     = "Lets CloudTrail publish Control Tower trail events to CloudWatch Logs."

  trust_policy_permissions = {
    CloudTrail = {
      actions    = ["sts:AssumeRole"]
      principals = [{ type = "Service", identifiers = ["cloudtrail.amazonaws.com"] }]
    }
  }

  policies = {
    AWSControlTowerCloudTrailRolePolicy = "arn:aws:iam::aws:policy/service-role/AWSControlTowerCloudTrailRolePolicy"
  }

  tags = var.tags
}

module "control_tower_stackset_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.8"
  count   = local.create_control_tower_roles ? 1 : 0

  name            = "AWSControlTowerStackSetRole"
  use_name_prefix = false
  path            = "/service-role/"
  description     = "Lets CloudFormation StackSets reach AWSControlTowerExecution in member accounts."

  trust_policy_permissions = {
    CloudFormation = {
      actions    = ["sts:AssumeRole"]
      principals = [{ type = "Service", identifiers = ["cloudformation.amazonaws.com"] }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    AssumeExecutionRole = {
      actions   = ["sts:AssumeRole"]
      resources = ["arn:aws:iam::*:role/AWSControlTowerExecution"]
    }
  }

  tags = var.tags
}
