# Upgrade Guide

Breaking changes and migration steps between versions, newest first.

## v2.0.0 — `github_environments` default changed to `[]`

The `github_environments` default changed from `["*"]` (wildcard) to `[]` (empty list), and wildcard values are now rejected by validation.

### Why

The previous `["*"]` default let workflows assume the role from **any** environment name, including ad-hoc or unprotected ones — bypassing GitHub Environment protection rules (required reviewers, wait timers, deployment branch restrictions). Users selecting `allow_environment` expected to restrict access to specific protected environments; the wildcard nullified that control.

### Migration

**If you relied on the wildcard default** — explicitly list your environments:

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/<repo>"

  default_conditions = ["allow_environment"]

  # REQUIRED: explicitly list allowed environments
  github_environments = ["production", "staging"]
}
```

**If you already specified environments** — no action required.

**If you don't use `allow_environment`** — no action required; the empty default has no effect.

Wildcards in environment names now fail validation:

```
Error: Wildcards are not allowed in environment names.
```

We recommend specific environment names rather than listing every environment, so you keep GitHub's environment protection features.

## `allow_all` removal

The `allow_all` preset is blocked by validation due to a critical fork privilege-escalation vulnerability (see [SECURITY.md](SECURITY.md#the-allow_all-vulnerability-deprecated-and-blocked)). If you used it, switch to a specific configuration:

```hcl
# ❌ BLOCKED — raises a validation error
default_conditions = ["allow_all"]

# ✅ Main branch only (safest)
default_conditions = ["allow_main", "deny_pull_request"]

# ✅ Main branch + PRs from the main repo only
default_conditions = ["allow_main", "allow_pull_request"]

# ✅ Environment-based deployments
default_conditions  = ["allow_environment"]
github_environments = ["production", "staging"]
```
