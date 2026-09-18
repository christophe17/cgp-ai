# Budget consolidé de l'organisation et détection de dépense anormale (docs/08 §8).
# Les budgets par compte membre sont créés dans chaque compte (infra/global/accounts/<env>).

module "budget_organization" {
  source = "../modules/budget"

  name                = "${var.project}-organization-monthly"
  limit_usd           = var.organization_budget_limit_usd
  notification_emails = var.budget_notification_emails
}

resource "aws_ce_anomaly_monitor" "services" {
  name              = "${var.project}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "email" {
  name             = "${var.project}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  dynamic "subscriber" {
    for_each = toset(var.budget_notification_emails)
    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }
}
