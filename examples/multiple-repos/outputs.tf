output "provider_arn" {
  description = "ARN of the OIDC provider owned by gh_repo_a and reused by gh_repo_b."
  value       = module.gh_repo_a.openid_connect_provider_arn
}

output "repo_a_role_name" {
  description = "IAM role name for repo-a."
  value       = module.gh_repo_a.assume_role.name
}

output "repo_b_role_name" {
  description = "IAM role name for repo-b (reuses repo-a's provider)."
  value       = module.gh_repo_b.assume_role.name
}
