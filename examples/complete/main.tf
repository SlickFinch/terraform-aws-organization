# A landing zone layout: Security, Infrastructure and Workloads (Prod and
# NonProd), with plus-addressed account emails, an SCP and an RCP.
# Run this from the Organization management account.

provider "aws" {
  region = "us-west-2"
}

# Take over an Organization and an account that already exist. Remove the
# import blocks once they are applied.
import {
  to = module.organization.aws_organizations_organization.this
  id = "o-exampleorg1"
}

import {
  to = module.organization.aws_organizations_account.this["dev"]
  id = "222222222222"
}

import {
  to = module.organization.aws_organizations_aws_service_access.this["sso.amazonaws.com"]
  id = "sso.amazonaws.com"
}

data "aws_iam_policy_document" "guardrails" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

module "organization" {
  source = "../.."

  aws_service_access_principals = ["sso.amazonaws.com", "account.amazonaws.com"]

  organizational_units = {
    Security       = {}
    Infrastructure = {}
    Workloads      = {}
    Prod           = { parent = "Workloads" }
    NonProd        = { parent = "Workloads" }
  }

  account_email_format = "aws+%s@example.com"

  accounts = {
    "example-log-archive" = { parent = "Security", email_alias = "log-archive" }
    "example-audit"       = { parent = "Security", email_alias = "audit" }
    "example-prod"        = { parent = "Prod", email_alias = "prod" }
    # An existing account keeps its own email.
    "dev" = { parent = "NonProd", email = "owner+dev@example.com" }
  }

  policies = {
    "example-guardrails" = {
      description = "Deny leaving the Organization."
      content     = data.aws_iam_policy_document.guardrails.json
      targets     = ["Security", "Infrastructure", "Workloads"]
    }
  }

  delegated_administrators = {
    "guardduty.amazonaws.com" = "example-audit"
  }

  alternate_contacts = {
    SECURITY = {
      name          = "Security Team"
      title         = "Security"
      email_address = "security@example.com"
      phone_number  = "+1-555-555-0100"
    }
  }

  tags = {
    ManagedBy = "opentofu"
  }
}

output "account_ids" {
  description = "Account IDs keyed by account key."
  value       = module.organization.account_ids
}
