# Enable product subscriptions to integrate findings from AWS security services
# These subscriptions allow Security Hub to receive findings from GuardDuty, Inspector, Macie, and Config
# Product subscriptions are created in the delegated administrator account (security account)

resource "aws_securityhub_product_subscription" "guardduty" {
  count = local.create_securityhub && var.product_subscriptions.guardduty ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/guardduty"
}

resource "aws_securityhub_product_subscription" "inspector" {
  count = local.create_securityhub && var.product_subscriptions.inspector ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/inspector"
}

resource "aws_securityhub_product_subscription" "macie" {
  count = local.create_securityhub && var.product_subscriptions.macie ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/macie"
}

resource "aws_securityhub_product_subscription" "config" {
  count = local.create_securityhub && var.product_subscriptions.config ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/config"
}

resource "aws_securityhub_product_subscription" "access_analyzer" {
  count = local.create_securityhub && var.product_subscriptions.access_analyzer ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/access-analyzer"
}

resource "aws_securityhub_product_subscription" "firewall_manager" {
  count = local.create_securityhub && var.product_subscriptions.firewall_manager ? 1 : 0

  depends_on  = [module.security_hub]
  product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/firewall-manager"
}
