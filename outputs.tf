output "conditions" {
  description = "The assumed repository conditions added to the role."
  value       = local.merge_conditions
}
output "openid_connect_provider_arn" {
  description = "AWS OpenID Connected identity provider arn."
  value       = local.openid_provider_arn
}
output "assume_role" {
  description = "The created role that can be assumed to configure the repository."
  value       = aws_iam_role.main
}