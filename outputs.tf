output "role" {
  description = "The created role that can be assumed to configure the repository."
  value       = var.repo != null ? aws_iam_role.main[0] : null
}

output "conditions" {
  description = "The assumed repository conditions added to the role."
  value       = local.merge_conditions
}