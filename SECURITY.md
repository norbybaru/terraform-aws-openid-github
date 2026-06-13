# Security

This module grants GitHub Actions workflows the ability to assume an AWS IAM role. Misconfigured conditions can expose your AWS account, so always apply the principle of least privilege: only grant access to the branches, environments, or events that genuinely need it.

## The `allow_all` vulnerability (deprecated and blocked)

The `allow_all` preset is **blocked** by validation — using it raises an error.

It built the OIDC `sub` claim pattern `repo:<org>/<repo>:*`. The `*` wildcard matched **every** sub-claim, including pull requests from **forked** repositories. That allowed an attacker to:

1. Fork your public repository.
2. Modify a GitHub Actions workflow in the fork to access AWS.
3. Trigger the workflow — GitHub issues an OIDC token with `sub: repo:<org>/<repo>:pull_request`.
4. Your role accepted the token because it matched `repo:<org>/<repo>:*`.
5. The attacker assumed your role and gained access to your AWS resources (data exfiltration, resource manipulation, cost inflation, pipeline compromise).

If you previously used `allow_all`, see [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md#allow_all-removal) to migrate.

## Recommended configurations

### Main branch only (most secure)

Production deployments from `main` only; pull requests (including forks) are denied.

```hcl
default_conditions = ["allow_main", "deny_pull_request"]
```

### Main branch + pull requests from the main repository

Enables pre-merge testing for trusted contributors. `allow_pull_request` only matches PRs from the **main repository**, not forks. Pair with branch protection rules.

```hcl
default_conditions = ["allow_main", "allow_pull_request"]
```

### Environment-based deployments (most flexible)

Leverages GitHub Environment protection rules (required reviewers, wait timers, branch restrictions).

```hcl
default_conditions  = ["allow_environment"]
github_environments = ["production", "staging"]
```

## Defense-in-depth with `deny_pull_request`

`deny_pull_request` explicitly blocks pull-request workflows from assuming the role, acting as a safety net alongside `allow_main`. Use it for production roles and roles with sensitive permissions.

```hcl
default_conditions = ["allow_main", "deny_pull_request"]
```

Evaluation with the configuration above:

| Trigger | Result |
|---|---|
| Push to `main` | ✅ Allowed (matches `allow_main`) |
| Pull request from main repo | ❌ Denied (`deny_pull_request`) |
| Pull request from fork | ❌ Denied (`deny_pull_request`) |
| Tag / release | ❌ Denied (no matching allow) |

Always include `deny_pull_request` when using `allow_main` for production roles — it makes the security intent explicit.

## Additional recommendations

**Use separate roles per environment/workflow** so you can apply different controls:

```hcl
module "gh_openid_prod" {
  source             = "github.com/norbybaru/terraform-aws-openid-github"
  repo               = "<org>/<repo>"
  role_name          = "github-actions-prod"
  default_conditions = ["allow_main", "deny_pull_request"]
}

module "gh_openid_dev" {
  source             = "github.com/norbybaru/terraform-aws-openid-github"
  repo               = "<org>/<repo>"
  role_name          = "github-actions-dev"
  default_conditions = ["allow_main", "allow_pull_request"]
}
```

**Scope IAM permissions** on the assumed role to specific actions and resources — avoid `s3:*` / `resources = ["*"]`.

**Audit role assumption** via CloudTrail, e.g. a metric filter on `AssumeRoleWithWebIdentity` for `module.gh_openid.assume_role.arn`.

**Use custom claim conditions** (`additional_conditions`) for fine-grained control:

```hcl
additional_conditions = [
  {
    test     = "StringLike"
    variable = "token.actions.githubusercontent.com:sub"
    values   = ["repo:<org>/<repo>:ref:refs/heads/main"]
  }
]
```

## OIDC thumbprints

AWS now automatically obtains and manages certificate thumbprints for GitHub's OIDC provider. Leave `thumb_prints` empty (default `[]`):

- AWS ignores manually specified thumbprints for `token.actions.githubusercontent.com`.
- An empty list lets AWS manage certificate rotation automatically.

See the [AWS documentation on OIDC provider thumbprints](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html).
