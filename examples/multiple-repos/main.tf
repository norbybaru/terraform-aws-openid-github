# Two repositories sharing one account-unique OIDC provider.
# gh_repo_a owns the provider; gh_repo_b reuses it via gh_repo_a's output.
# create_openid_provider = false keeps gh_repo_b's count plan-time-known even
# though the ARN is computed (known after apply) — the case that previously
# failed with "Invalid count argument".

module "gh_repo_a" {
  source = "../../"
  repo   = "example-org/repo-a"

  create_openid_provider = true
}

module "gh_repo_b" {
  source = "../../"
  repo   = "example-org/repo-b"

  create_openid_provider      = false
  openid_connect_provider_arn = module.gh_repo_a.openid_connect_provider_arn
}
