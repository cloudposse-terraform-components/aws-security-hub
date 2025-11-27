# Security Hub Product Subscriptions

## Overview

Product subscriptions have been added to the Security Hub component to enable automatic finding integration from AWS
security services. This enables Security Hub to receive and aggregate findings from GuardDuty, Inspector, Macie, Config,
Access Analyzer, and Firewall Manager.

## What Was Added

### New Resources

The following product subscription resources were added to `main.tf`:

1. **GuardDuty** - Threat detection findings
2. **Inspector** - Vulnerability scanning findings
3. **Macie** - Sensitive data discovery findings
4. **Config** - Configuration compliance findings
5. **Access Analyzer** - External access findings
6. **Firewall Manager** - Firewall policy compliance findings

### Code Changes

**File: `product_subscriptions.tf`**

- 6 product subscription resources for AWS security service integrations
- All resources use partition-aware ARN format: `arn:${data.aws_partition.this[0].partition}:...`
- Resources are conditionally created only in delegated administrator account
- Resources depend on `module.security_hub` to ensure proper creation order

**File: `main.tf`**

- Added `data.aws_partition` data source for GovCloud-aware ARNs

**File: `outputs.tf`**

- Added `product_subscriptions` output with ARNs of all subscriptions

**File: `README.md`**

- Regenerated with terraform-docs to include new resources
- Documents product subscription resources
- Documents partition data source
- Documents product_subscriptions output

## How Product Subscriptions Work

### Without Product Subscriptions (Previous State)

```
GuardDuty Findings  ──▶  GuardDuty Console Only
Inspector Findings  ──▶  Inspector Console Only
Macie Findings      ──▶  Macie Console Only
Config Findings     ──▶  Config Console Only

Security Hub        ──▶  Empty / No Findings

Result: Security team must check 4+ different consoles
```

### With Product Subscriptions (Current State)

```
GuardDuty Findings  ──▶  Security Hub  ◀──  All Findings
Inspector Findings  ──▶  Security Hub        Aggregated
Macie Findings      ──▶  Security Hub        in One Place
Config Findings     ──▶  Security Hub

Security Hub        ──▶  Complete Security Posture Dashboard

Result: Single pane of glass for all security findings
```

## Deployment

### Prerequisites

Before deploying the updated component:

1. ✅ Security Hub must already be deployed (3-step deployment completed)
2. ✅ Source services should be deployed and operational:
    - GuardDuty
    - Inspector2
    - Macie
    - Config
    - Access Analyzer
    - (Firewall Manager optional)

### Deployment Steps

Product subscriptions are automatically created when you deploy/update the Security Hub component in the delegated
administrator account (security account).

**Step 1: Deploy to Security Account (Delegated Administrator)**

```bash
# This is the Step 1 deployment (or update if already deployed)
atmos terraform apply aws-security-hub/delegated-administrator -s mgmt-use1-security
```

This will:

- Create or update Security Hub
- **NEW**: Create product subscriptions for all AWS security services
- Enable finding integration automatically

**Step 2: Deploy to Management Account (if not already done)**

```bash
# This is the Step 2 deployment (delegation)
atmos terraform apply aws-security-hub/root -s mgmt-use1-jcfsit
```

**Step 3: Configure Organization Settings (if not already done)**

```bash
# This is the Step 3 deployment (organization configuration)
atmos terraform apply aws-security-hub/org-settings -s mgmt-use1-security
```

**For Additional Regions:**

Repeat Step 1 in each region where security services are deployed:

```bash
# us-gov-west-1 example
atmos terraform apply aws-security-hub/delegated-administrator -s mgmt-usw1-security
```

### Verification

After deployment, verify product subscriptions are active:

**Option 1: Check Terraform Outputs**

```bash
atmos terraform output aws-security-hub/delegated-administrator -s mgmt-use1-security
```

Look for `product_subscriptions` output with ARNs for each subscription.

**Option 2: AWS CLI**

```bash
# List enabled product subscriptions
aws securityhub list-enabled-products-for-import \
  --region us-gov-east-1

# Expected output:
# [
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/guardduty",
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/inspector",
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/macie",
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/config",
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/access-analyzer",
#   "arn:aws-us-gov:securityhub:us-gov-east-1::product/aws/firewall-manager"
# ]
```

**Option 3: AWS Console**

1. Navigate to Security Hub in the security account
2. Go to **Integrations** → **Product integrations**
3. Verify all AWS services show "Enabled" status

**Option 4: Check for Findings**

```bash
# List findings by product (GuardDuty example)
aws securityhub get-findings \
  --filters '{"ProductName":[{"Value":"GuardDuty","Comparison":"EQUALS"}]}' \
  --region us-gov-east-1 \
  --max-items 5
```

**Note**: It may take 5-15 minutes for existing findings to flow to Security Hub after enabling subscriptions.

## GovCloud Considerations

### Partition-Aware ARNs

All product subscription ARNs use the partition-aware format:

```hcl
product_arn = "arn:${data.aws_partition.this[0].partition}:securityhub:${data.aws_region.this[0].name}::product/aws/guardduty"
```

**Automatically resolves to:**

- Commercial AWS: `arn:aws:securityhub:...`
- GovCloud: `arn:aws-us-gov:securityhub:...`

This ensures the component works correctly in both partitions without modification.

### Service Availability

All product subscriptions configured are available in GovCloud:

| Product          | GovCloud Availability                   |
|------------------|-----------------------------------------|
| GuardDuty        | ✅ Available                             |
| Inspector        | ✅ Available                             |
| Macie            | ✅ Available                             |
| Config           | ✅ Available                             |
| Access Analyzer  | ✅ Available                             |
| Firewall Manager | ✅ Available (if using Firewall Manager) |

## Impact and Benefits

### Before Product Subscriptions

- **Fragmented View**: Security findings scattered across multiple consoles
- **Manual Correlation**: Security team manually correlates findings across services
- **Slow Response**: Must check each service individually for new findings
- **Incomplete Compliance**: Security Hub compliance standards missing data from other services
- **Alert Fatigue**: Multiple alert channels from different services

### After Product Subscriptions

- **Unified Dashboard**: All security findings in Security Hub console
- **Automated Correlation**: Security Hub automatically correlates related findings
- **Fast Response**: Single EventBridge integration for all findings
- **Complete Compliance**: Security Hub compliance standards assess all controls
- **Centralized Alerting**: One SNS topic for all security findings

### Compliance Impact

**Security Hub Compliance Standards** now have complete data:

- **AWS Foundational Security Best Practices**: All controls can be assessed
- **CIS AWS Foundations Benchmark**: Complete compliance posture
- **PCI DSS**: Full control assessment including GuardDuty, Config, Inspector
- **NIST 800-53**: Comprehensive security control validation

**Example**: Control "GuardDuty.1 - GuardDuty should be enabled"

- **Before**: Security Hub couldn't verify GuardDuty status
- **After**: Security Hub receives GuardDuty findings and validates control

## Automated Response

With product subscriptions enabled, you can create unified automated response workflows:

**Example: Automated Remediation for Critical Findings**

```hcl
# EventBridge rule for ANY critical finding from ANY service
resource "aws_cloudwatch_event_rule" "critical_findings" {
  name = "security-hub-critical-findings"

  event_pattern = jsonencode({
    source = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL"]
        }
      }
    }
  })
}

# Route to Lambda for automated remediation
resource "aws_cloudwatch_event_target" "remediation" {
  rule      = aws_cloudwatch_event_rule.critical_findings.name
  target_id = "RemediationLambda"
  arn       = aws_lambda_function.security_remediation.arn
}

# This single rule now handles critical findings from:
# - GuardDuty (threats)
# - Inspector (vulnerabilities)
# - Macie (data exposure)
# - Config (compliance violations)
# - Access Analyzer (unintended access)
```

## Troubleshooting

### Product Subscription Creation Fails

**Symptom**: Terraform error creating product subscription

**Possible Causes**:

1. Security Hub not fully enabled before subscription creation
2. Incorrect product ARN format
3. Service not available in region

**Solution**:

- Ensure Security Hub is fully deployed first
- Verify `depends_on = [module.security_hub]` is present
- Check product ARN uses correct partition and region

### Findings Not Appearing in Security Hub

**Symptom**: Product subscription exists but no findings appear

**Troubleshooting Steps**:

1. **Verify source service is enabled and generating findings**:
   ```bash
   # Check GuardDuty has findings
   aws guardduty list-findings --detector-id <detector-id> --region us-gov-east-1
   ```

2. **Check product subscription is active**:
   ```bash
   aws securityhub list-enabled-products-for-import --region us-gov-east-1
   ```

3. **Allow time for finding propagation**: Can take 5-15 minutes initially

4. **Check IAM permissions**: Security Hub must have permission to receive findings

5. **Verify both services in same region**: Product subscriptions are regional

### Duplicate Findings

**Symptom**: Same finding appears multiple times

**Cause**: Product subscription created in multiple regions or accounts incorrectly

**Solution**: Product subscriptions should only exist in delegated administrator account, not member accounts

## Cost Considerations

**Product Subscriptions**: Free (no additional cost for subscriptions themselves)

**Security Hub Pricing**:

- **Finding Ingestion**: $0.0010 per finding after free tier (10,000 findings/month free)
- **Security Checks**: $0.0010 per check after free tier (100,000 checks/month free)
- **More findings**: More ingested findings = higher cost

**Cost Optimization**:

- Use finding filters to suppress low-value findings
- Archive resolved findings
- Configure retention policies
- Monitor finding volume in CloudWatch

**Estimated Impact** (example org with 50 accounts):

- Before subscriptions: ~1,000 Security Hub findings/month
- After subscriptions: ~10,000-50,000 findings/month (includes GuardDuty, Inspector, Macie, Config)
- Cost increase: ~$40-50/month per region (after free tier)

**Value**: Centralized security posture management worth the cost for most organizations.

## Next Steps

After enabling product subscriptions:

1. **Verify Findings Flow**: Check Security Hub console for findings from all services
2. **Configure Insights**: Create custom insights for your organization's security priorities
3. **Set Up Alerts**: Configure SNS topics for critical/high severity findings
4. **Automated Remediation**: Create EventBridge rules and Lambda functions for common findings
5. **Enable Finding Aggregation**: Configure cross-region finding aggregation in us-gov-east-1
6. **Review Compliance**: Check compliance standards now show complete control assessment

## References

- [Security Hub Product Integrations Documentation](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings-providers.html)
- [Security Hub Product Subscriptions API](https://docs.aws.amazon.com/securityhub/latest/APIReference/API_EnableImportFindingsForProduct.html)
- [Comprehensive Product Subscriptions Guide](../../../docs/compliance/aws-security-hub.md#product-subscriptions)
