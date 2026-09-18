# Budget mensuel avec alarmes à 50 %, 80 % et 100 % du réel et 100 % de la prévision
# (docs/08-production-readiness.md §8).

locals {
  actual_thresholds = [50, 80, 100]
}

resource "aws_budgets_budget" "monthly" {
  name              = var.name
  budget_type       = "COST"
  limit_amount      = tostring(var.limit_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = var.time_period_start

  dynamic "notification" {
    for_each = local.actual_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.notification_emails
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_emails
  }
}
