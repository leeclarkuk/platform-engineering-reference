terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

variable "name" {
  description = "Budget name."
  type        = string
}

variable "amount" {
  description = "Monthly budget in USD. This is an example ceiling, not a quote."
  type        = number
}

variable "email" {
  description = "Notification email. Use a platform alias, not a personal mailbox."
  type        = string
}

variable "tags" {
  description = "Cost allocation tags used as a budget filter when set."
  type        = map(string)
  default     = {}
}

resource "aws_budgets_budget" "monthly" {
  name              = var.name
  budget_type       = "COST"
  limit_amount      = tostring(var.amount)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"
  tags              = var.tags

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.email]
  }
}

output "budget_name" {
  description = "Budget name."
  value       = aws_budgets_budget.monthly.name
}
