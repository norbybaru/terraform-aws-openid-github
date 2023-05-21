locals {
  github_environments = (length(var.github_environments) > 0 && var.repo != null) ? [for e in var.github_environments : "repo:${var.repo}:environment:${e}"] : ["nothing"]
  github_sub          = "token.actions.githubusercontent.com:sub"
  role_name           = (var.repo != null && var.role_name != null) ? var.role_name : "${replace(var.repo != null ? var.repo : "", "/", "-")}-role"
  openid_provider_arn = var.openid_connect_provider_arn != null ? var.openid_connect_provider_arn : aws_iam_openid_connect_provider.openid_connect[0].arn

  default_allow_main = contains(var.default_conditions, "allow_main") ? [{
    test     = "StringLike"
    variable = local.github_sub
    values   = ["repo:${var.repo}:ref:refs/heads/main"]
  }] : []

  default_allow_environment = contains(var.default_conditions, "allow_environment") ? [{
    test     = "StringLike"
    variable = local.github_sub
    values   = local.github_environments
  }] : []

  default_allow_all = contains(var.default_conditions, "allow_all") ? [{
    test     = "StringLike"
    variable = local.github_sub
    values   = ["repo:${var.repo}:*"]
  }] : []

  default_deny_pull_request = contains(var.default_conditions, "deny_pull_request") ? [{
    test     = "StringNotLike"
    variable = local.github_sub
    values   = ["repo:${var.repo}:pull_request"]
  }] : []

  default_allow_pull_request = contains(var.default_conditions, "allow_pull_request") && !contains(var.default_conditions, "deny_pull_request") ? [{
    test     = "StringLike"
    variable = local.github_sub
    values   = ["repo:${var.repo}:pull_request"]
  }] : []

  conditions = setunion(local.default_allow_main, local.default_allow_environment, local.default_allow_all, local.default_deny_pull_request, local.default_allow_pull_request, var.additional_conditions)

  merge_conditions = [
    for k, v in { for c in local.conditions : "${c.test}|${c.variable}" => c... } : # group by test & variable
    {
      "test" : k,
      "values" : flatten([for index, sp in v[*].values : v[index].values if v[index].variable == v[0].variable]) # loop again to build the values inner map
    }
  ]
}