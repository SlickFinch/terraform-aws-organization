variable "feature_set" {
  description = "Organization feature set: ALL or CONSOLIDATED_BILLING. Policies, delegated administrators and trusted access need ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.feature_set)
    error_message = "feature_set must be ALL or CONSOLIDATED_BILLING."
  }
}

variable "enabled_policy_types" {
  description = "Policy types to enable on the root, in addition to the types used in var.policies. Valid values: AISERVICES_OPT_OUT_POLICY, BACKUP_POLICY, BEDROCK_POLICY, CHATBOT_POLICY, DECLARATIVE_POLICY_EC2, INSPECTOR_POLICY, RESOURCE_CONTROL_POLICY, S3_POLICY, SECURITYHUB_POLICY, SERVICE_CONTROL_POLICY, TAG_POLICY, UPGRADE_ROLLOUT_POLICY."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([for t in var.enabled_policy_types : contains([
      "AISERVICES_OPT_OUT_POLICY", "BACKUP_POLICY", "BEDROCK_POLICY", "CHATBOT_POLICY",
      "DECLARATIVE_POLICY_EC2", "INSPECTOR_POLICY", "RESOURCE_CONTROL_POLICY", "S3_POLICY",
      "SECURITYHUB_POLICY", "SERVICE_CONTROL_POLICY", "TAG_POLICY", "UPGRADE_ROLLOUT_POLICY",
    ], t)])
    error_message = "enabled_policy_types has an unknown policy type."
  }
}

variable "aws_service_access_principals" {
  description = "Service principals to give trusted access to the Organization, for example sso.amazonaws.com. Each one is its own resource, so services that enable their own access (Control Tower, for example) don't cause drift."
  type        = list(string)
  default     = []
}

variable "organizational_units" {
  description = "OUs keyed by a stable key. parent is the key of another OU in this map, or null for the root. name defaults to the key. OUs can nest up to 5 levels deep."
  type = map(object({
    name   = optional(string)
    parent = optional(string)
    tags   = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for ou in values(var.organizational_units) : ou.parent == null || contains(keys(var.organizational_units), coalesce(ou.parent, "-"))
    ])
    error_message = "Every OU parent must be the key of another OU in organizational_units, or null for the root."
  }
}

variable "accounts" {
  description = <<-EOT
    Member accounts keyed by account name.
    - email: full email address. If null, the module builds it from account_email_format.
    - email_alias: value put into account_email_format. Defaults to the map key.
    - name: account name. Defaults to the map key.
    - parent: key of an OU in organizational_units. parent_id: an OU or root ID managed elsewhere. If both are null, the account goes under the root.
    - close_on_deletion: close the account when the resource is destroyed. Accounts also have prevent_destroy.
    - iam_user_access_to_billing and role_name only apply at creation. The module ignores later changes, so imported accounts don't show a diff.
  EOT
  type = map(object({
    email                      = optional(string)
    email_alias                = optional(string)
    name                       = optional(string)
    parent                     = optional(string)
    parent_id                  = optional(string)
    close_on_deletion          = optional(bool, false)
    iam_user_access_to_billing = optional(string)
    role_name                  = optional(string)
    tags                       = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for a in values(var.accounts) : !(a.parent != null && a.parent_id != null)])
    error_message = "Set parent or parent_id on an account, not both."
  }

  validation {
    condition     = alltrue([for a in values(var.accounts) : a.parent == null || contains(keys(var.organizational_units), coalesce(a.parent, "-"))])
    error_message = "An account parent must be the key of an OU in organizational_units."
  }

  validation {
    condition     = alltrue([for a in values(var.accounts) : a.iam_user_access_to_billing == null || contains(["ALLOW", "DENY"], coalesce(a.iam_user_access_to_billing, "-"))])
    error_message = "iam_user_access_to_billing must be ALLOW or DENY."
  }
}

variable "account_email_format" {
  description = "format() string for account emails that aren't set explicitly, for example \"aws+%s@example.com\" for plus addressing. The %s gets the account's email_alias, or its key."
  type        = string
  default     = null

  validation {
    condition     = var.account_email_format == null || can(regex("^[^@]*%s[^@]*@[^@]+$", var.account_email_format))
    error_message = "account_email_format must contain %s in the local part, for example aws+%s@example.com."
  }
}

variable "policies" {
  description = <<-EOT
    Organization policies keyed by policy name.
    - type: policy type. Defaults to SERVICE_CONTROL_POLICY. The module enables every type used here on the root.
    - targets: where to attach the policy. Each entry is "root", an OU key, an account key, or a literal root, OU or account ID.
    - skip_destroy: keep the policy (and its attachments) in AWS when it leaves the configuration.
  EOT
  type = map(object({
    content      = string
    type         = optional(string, "SERVICE_CONTROL_POLICY")
    description  = optional(string)
    targets      = optional(list(string), [])
    skip_destroy = optional(bool, false)
    tags         = optional(map(string), {})
  }))
  default = {}
}

variable "delegated_administrators" {
  description = "Delegated administrators as service principal => account. The account is an account key from var.accounts or a 12-digit account ID."
  type        = map(string)
  default     = {}
}

variable "resource_policy" {
  description = "JSON resource policy for the Organization, which delegates Organizations read or management actions to member accounts. Null to manage none."
  type        = string
  default     = null
}

variable "alternate_contacts" {
  description = "Alternate contacts (BILLING, OPERATIONS, SECURITY) set on every account this module manages. Needs trusted access for account.amazonaws.com."
  type = map(object({
    name          = string
    title         = string
    email_address = string
    phone_number  = string
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.alternate_contacts) : contains(["BILLING", "OPERATIONS", "SECURITY"], k)])
    error_message = "alternate_contacts keys must be BILLING, OPERATIONS or SECURITY."
  }
}

variable "tags" {
  description = "Tags for every taggable resource. Per-resource tags win on conflict."
  type        = map(string)
  default     = {}
}
