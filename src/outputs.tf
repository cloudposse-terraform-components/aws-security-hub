output "delegated_administrator_account_id" {
  value       = local.org_delegated_administrator_account_id
  description = "The AWS Account ID of the AWS Organization delegated administrator account"
}

output "sns_topic_name" {
  value       = local.create_securityhub ? try(module.security_hub[0].sns_topic.name, null) : null
  description = "The name of the SNS topic created by the component"
}

output "sns_topic_subscriptions" {
  value       = local.create_securityhub ? try(module.security_hub[0].sns_topic_subscriptions, null) : null
  description = "The SNS topic subscriptions created by the component"
}

output "product_subscriptions" {
  value = local.create_securityhub ? {
    guardduty        = try(aws_securityhub_product_subscription.guardduty[0].arn, null)
    inspector        = try(aws_securityhub_product_subscription.inspector[0].arn, null)
    macie            = try(aws_securityhub_product_subscription.macie[0].arn, null)
    config           = try(aws_securityhub_product_subscription.config[0].arn, null)
    access_analyzer  = try(aws_securityhub_product_subscription.access_analyzer[0].arn, null)
    firewall_manager = try(aws_securityhub_product_subscription.firewall_manager[0].arn, null)
  } : null
  description = "ARNs of Security Hub product subscriptions for AWS service integrations"
}
