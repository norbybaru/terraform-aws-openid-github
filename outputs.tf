output "conditions" {
  description = "The assumed repository conditions added to the role."
  value       = local.merge_conditions
}
output "openid_connect_provider_arn" {
  description = "AWS OpenID Connected identity provider arn."
  value       = local.openid_provider_arn
}
output "assume_role" {
  description = "The created IAM role that can be assumed to configure the repository. Curated attributes — avoids leaking the provider-deprecated inline_policy carried by the full resource object."
  value = {
    arn  = aws_iam_role.main.arn
    name = aws_iam_role.main.name
    id   = aws_iam_role.main.id
  }
}
