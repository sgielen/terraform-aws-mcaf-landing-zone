resource "aws_cloudtrail" "additional_auditing_trail" {
  count                 = var.additional_auditing_trail != null ? 1 : 0
  name                  = var.additional_auditing_trail.name
  s3_bucket_name        = var.additional_auditing_trail.bucket
  is_organization_trail = true
}

resource "aws_cloudwatch_event_rule" "monitor_iam_access_master" {
  for_each    = { for identity, identity_data in local.monitor_iam_access : identity => identity_data if try(identity_data.account, null) == "master" || identity == "Root" }
  name        = substr("LandingZone-MonitorIAMAccess-${each.key}", 0, 64)
  description = "Monitors IAM access for ${each.key}"

  event_pattern = templatefile("${path.module}/files/event_bridge/monitor_iam_access.json.tpl", {
    userIdentity = jsonencode(each.value.userIdentity)
  })

  depends_on = [
    data.aws_iam_role.monitor_iam_access_master,
    data.aws_iam_user.monitor_iam_access_master
  ]
}

resource "aws_cloudwatch_event_target" "monitor_iam_access_master" {
  for_each   = aws_cloudwatch_event_rule.monitor_iam_access_master
  arn        = aws_cloudwatch_event_bus.monitor_iam_access_audit.arn
  role_arn   = aws_iam_role.monitor_iam_access_master.arn
  rule       = each.value.name
  target_id  = "SendToAuditEventBus"
  depends_on = [aws_cloudwatch_event_permission.organization_access_audit]
}

resource "aws_config_aggregate_authorization" "master" {
  for_each   = { for aggregator in local.aws_config_aggregators : "${aggregator.account_id}-${aggregator.region}" => aggregator if aggregator.account_id != var.control_tower_account_ids.audit }
  account_id = each.value.account_id
  region     = each.value.region
}

resource "aws_config_aggregate_authorization" "master_to_audit" {
  for_each   = toset(try(var.aws_config.aggregator_regions, ["eu-central-1", "eu-west-1"]))
  account_id = var.control_tower_account_ids.audit
  region     = each.value
}

resource "aws_config_configuration_recorder" "default" {
  name     = "default"
  role_arn = aws_iam_role.config_recorder.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_guardduty_detector" "master" {
  count = var.aws_guardduty == true ? 1 : 0
}

resource "aws_guardduty_organization_admin_account" "audit" {
  count            = var.aws_guardduty == true ? 1 : 0
  admin_account_id = var.control_tower_account_ids.audit
}

resource "aws_config_configuration_recorder_status" "default" {
  name       = aws_config_configuration_recorder.default.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.default]
}

resource "aws_config_delivery_channel" "default" {
  name           = "default"
  s3_bucket_name = "aws-controltower-logs-${var.control_tower_account_ids.logging}-${data.aws_region.current.name}"
  s3_key_prefix  = data.aws_organizations_organization.default.id
  sns_topic_arn  = data.aws_sns_topic.all_config_notifications.arn
  depends_on     = [aws_config_configuration_recorder.default]
}

resource "aws_config_organization_managed_rule" "default" {
  for_each        = toset(local.aws_config_rules)
  name            = each.value
  rule_identifier = each.value
}

resource "aws_iam_role" "config_recorder" {
  name = "LandingZone-ConfigRecorderRole"

  assume_role_policy = templatefile("${path.module}/files/iam/service_assume_role.json.tpl", {
    service = "config.amazonaws.com"
  })
}

resource "aws_iam_role" "monitor_iam_access_master" {
  name               = "LandingZone-MonitorIAMAccess"
  assume_role_policy = templatefile("${path.module}/files/iam/service_assume_role.json.tpl", { service = "events.amazonaws.com" })
  tags               = var.tags
}

resource "aws_iam_role_policy" "monitor_iam_access_master" {
  name   = "LandingZone-MonitorIAMAccess"
  role   = aws_iam_role.monitor_iam_access_logging.id
  policy = data.aws_iam_policy_document.monitor_iam_access.json
}

resource "aws_iam_role_policy_attachment" "config_recorder_read_only" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "config_recorder_config_role" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

module "datadog_master" {
  count                 = try(var.datadog.enable_integration, false) == true ? 1 : 0
  source                = "github.com/schubergphilis/terraform-aws-mcaf-datadog?ref=v0.3.3"
  api_key               = try(var.datadog.api_key, null)
  install_log_forwarder = try(var.datadog.install_log_forwarder, false)
  site_url              = try(var.datadog.site_url, null)
  tags                  = var.tags
}

module "kms_key" {
  source      = "github.com/schubergphilis/terraform-aws-mcaf-kms?ref=v0.1.5"
  name        = "inception"
  description = "KMS key used for encrypting SSM parameters"
  tags        = var.tags
}

module "security_hub_master" {
  source                          = "./modules/security_hub"
  account_id                      = data.aws_caller_identity.current.account_id
  sns_endpoint                    = var.sns_endpoint
  sns_endpoint_protocol           = var.sns_endpoint_protocol
  sns_security_topic_subscription = var.sns_security_topic_subscription
}
