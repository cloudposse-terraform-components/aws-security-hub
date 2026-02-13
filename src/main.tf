locals {
  enabled     = module.this.enabled
  account_map = module.account_map.outputs.full_account_map

  current_account_id                     = one(data.aws_caller_identity.this[*].account_id)
  member_account_id_list                 = [for a in keys(local.account_map) : (local.account_map[a]) if local.account_map[a] != local.current_account_id && local.account_map[a] != local.org_management_account_id]
  org_delegated_administrator_account_id = local.account_map[var.delegated_administrator_account_name]
  org_management_account_id              = var.organization_management_account_name == null ? local.account_map[module.account_map.outputs.root_account_account_name] : local.account_map[var.organization_management_account_name]
  is_org_delegated_administrator_account = local.current_account_id == local.org_delegated_administrator_account_id
  is_org_management_account              = local.current_account_id == local.org_management_account_id
  is_finding_aggregation_region          = local.enabled && var.finding_aggregator_enabled && var.finding_aggregation_region == data.aws_region.this[0].name

  create_sns_topic         = local.enabled && var.create_sns_topic
  create_securityhub       = local.enabled && local.is_org_delegated_administrator_account && !var.admin_delegated
  create_org_delegation    = local.enabled && local.is_org_management_account
  create_org_configuration = local.enabled && local.is_org_delegated_administrator_account && var.admin_delegated

  # Common values used in the delegation policy
  partition                 = local.enabled ? data.aws_partition.this[0].partition : ""
  org_id                    = local.enabled ? data.aws_organizations_organization.this[0].id : ""
  delegated_admin_principal = "arn:${local.partition}:iam::${local.org_delegated_administrator_account_id}:root"
  org_resource_arn_prefix   = "arn:${local.partition}:organizations::${local.org_management_account_id}"

  # Organization resource ARNs for the delegation policy (scoped to org ID)
  org_scoped_resource_arns = [
    "${local.org_resource_arn_prefix}:root/${local.org_id}/*",
    "${local.org_resource_arn_prefix}:ou/${local.org_id}/*",
    "${local.org_resource_arn_prefix}:account/${local.org_id}/*",
    "${local.org_resource_arn_prefix}:policy/${local.org_id}/securityhub_policy/*",
    "${local.org_resource_arn_prefix}:policy/${local.org_id}/inspector_policy/*",
  ]
}

data "aws_caller_identity" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_region" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_partition" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_organizations_organization" "this" {
  count = local.enabled ? 1 : 0
}

# If we are running in the AWS Org Management account, delegate Security Hub to the Delegated Administrator account
# (usually the security account). We also need to turn on Security Hub in the Management account so that it can
# aggregate findings and be managed by the Delegated Administrator account.
resource "aws_securityhub_organization_admin_account" "this" {
  count = local.create_org_delegation ? 1 : 0

  admin_account_id = local.org_delegated_administrator_account_id
}

resource "aws_securityhub_account" "this" {
  count = local.create_org_delegation ? 1 : 0

  enable_default_standards = var.default_standards_enabled
}

# Organizations resource-based delegation policy for Security Hub.
# This grants the delegated administrator account permissions to manage Security Hub policies
# via Organizations APIs. The policy must include ALL 8 statements that AWS expects, including the
# SecurityServicesDelegating* statements with specific resource ARNs scoped to the organization.
# See: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-v2-policy-statement.html
#
# IMPORTANT: aws_organizations_resource_policy is an organization-wide singleton. Only one can exist per
# organization. If other services need delegation policies, their statements must be combined here.
resource "aws_organizations_resource_policy" "security_hub" {
  count = local.create_org_delegation ? 1 : 0

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DelegatingNecessaryDescribeListActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action = [
          "organizations:DescribeOrganization",
          "organizations:DescribeOrganizationalUnit",
          "organizations:DescribeAccount",
          "organizations:DescribePolicy",
          "organizations:DescribeEffectivePolicy",
          "organizations:DescribeResourcePolicy",
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:ListParents",
          "organizations:ListChildren",
          "organizations:ListAccounts",
          "organizations:ListAccountsForParent",
          "organizations:ListPolicies",
          "organizations:ListPoliciesForTarget",
          "organizations:ListTargetsForPolicy",
          "organizations:ListTagsForResource",
          "organizations:ListDelegatedAdministrators",
          "organizations:ListAWSServiceAccessForOrganization",
        ]
        Resource = "*"
      },
      {
        Sid       = "DelegatingSecurityHubPolicyActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action = [
          "organizations:CreatePolicy",
          "organizations:UpdatePolicy",
          "organizations:DeletePolicy",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy",
          "organizations:EnablePolicyType",
          "organizations:DisablePolicyType",
        ]
        Resource  = "*"
        Condition = { StringLikeIfExists = { "organizations:PolicyType" = ["SECURITYHUB_POLICY"] } }
      },
      {
        Sid       = "DelegatingSecurityHubPolicyTagging"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action    = ["organizations:TagResource", "organizations:UntagResource", "organizations:ListTagsForResource"]
        Resource  = "*"
        Condition = { StringLikeIfExists = { "organizations:PolicyType" = ["SECURITYHUB_POLICY"] } }
      },
      {
        Sid       = "SecurityServicesDelegatingOrgReadActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action    = "organizations:ListRoots"
        Resource  = "*"
      },
      {
        Sid       = "SecurityServicesDelegatingNecessaryOrgManagementActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action = [
          "organizations:DescribeOrganization",
          "organizations:DescribeOrganizationalUnit",
          "organizations:DescribeAccount",
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:ListParents",
          "organizations:ListChildren",
          "organizations:ListAccounts",
          "organizations:ListAccountsForParent",
          "organizations:ListTagsForResource",
          "organizations:ListDelegatedAdministrators",
          "organizations:ListHandshakesForAccount",
        ]
        Resource = concat(
          local.org_scoped_resource_arns,
          ["${local.org_resource_arn_prefix}:organization/${local.org_id}"],
        )
      },
      {
        Sid       = "SecurityServicesDelegatingPolicyDescribeActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action = [
          "organizations:DescribePolicy",
          "organizations:DescribeEffectivePolicy",
          "organizations:ListPolicies",
          "organizations:ListPoliciesForTarget",
          "organizations:ListTargetsForPolicy",
        ]
        Resource = local.org_scoped_resource_arns
      },
      {
        Sid       = "SecurityServicesDelegatingPolicyMutationActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action = [
          "organizations:CreatePolicy",
          "organizations:UpdatePolicy",
          "organizations:DeletePolicy",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy",
          "organizations:EnablePolicyType",
          "organizations:DisablePolicyType",
        ]
        Resource = local.org_scoped_resource_arns
      },
      {
        Sid       = "SecurityServicesDelegatingPolicyTagActions"
        Effect    = "Allow"
        Principal = { AWS = local.delegated_admin_principal }
        Action    = ["organizations:TagResource", "organizations:UntagResource"]
        Resource = [
          "${local.org_resource_arn_prefix}:policy/${local.org_id}/securityhub_policy/*",
          "${local.org_resource_arn_prefix}:policy/${local.org_id}/inspector_policy/*",
        ]
      },
    ]
  })
}

# If we are running in the AWS Org designated administrator account, enable Security Hub and optionally enable standards
# and finding aggregation
module "security_hub" {
  count   = local.create_securityhub ? 1 : 0
  source  = "cloudposse/security-hub/aws"
  version = "0.12.2"


  cloudwatch_event_rule_pattern_detail_type = var.cloudwatch_event_rule_pattern_detail_type
  create_sns_topic                          = local.create_sns_topic
  enable_default_standards                  = var.default_standards_enabled
  enabled_standards                         = var.enabled_standards
  finding_aggregator_enabled                = local.is_finding_aggregation_region
  finding_aggregator_linking_mode           = var.finding_aggregator_linking_mode
  finding_aggregator_regions                = var.finding_aggregator_regions
  imported_findings_notification_arn        = var.findings_notification_arn
  subscribers                               = var.subscribers

  context = module.this.context
}

# If we are running in the AWS Org designated administrator account with admin_delegated set to true, set the AWS
# Organization-wide Security Hub configuration by configuring all other accounts to send their Security Hub findings to
# this account.
resource "awsutils_security_hub_organization_settings" "this" {
  count = local.create_org_configuration ? 1 : 0

  member_accounts = local.member_account_id_list

  depends_on = [aws_securityhub_organization_configuration.this]
}

resource "aws_securityhub_organization_configuration" "this" {
  count = local.create_org_configuration ? 1 : 0

  auto_enable           = var.auto_enable_organization_members
  auto_enable_standards = var.default_standards_enabled ? "DEFAULT" : "NONE"

  organization_configuration {
    configuration_type = "LOCAL"
  }
}
