output "budget_name" {
  description = "Nom du budget créé."
  value       = aws_budgets_budget.monthly.name
}
