# Terraform Github Action OpenID Connect Provider
This module manages OpenID Connect (OIDC) integration between [GitHub Actions and AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

The module can manage the following:
- The OpenID Connect identity provider for GitHub in your AWS account (via a submodule).
- A role and assume role policy to check to check OIDC claims.

## ⚠️ Security Notice: allow_all Deprecated

The `allow_all` condition has been **deprecated and blocked** due to a critical security vulnerability (CVE-level severity).

**Issue**: The previous implementation used the pattern `repo:<org>/<repo>:*` which matched ALL GitHub OIDC sub-claims, including pull requests from forked repositories. This allowed attackers to:
1. Fork your public repository
2. Trigger GitHub Actions workflows  
3. Assume your AWS IAM role
4. Access your AWS resources

**Migration Required**: If you were using `allow_all`, you must update your configuration:

```hcl
# ❌ BLOCKED - Will cause validation error
default_conditions = ["allow_all"]

# ✅ Recommended - Main branch only (safest)
default_conditions = ["allow_main", "deny_pull_request"]

# ✅ Alternative - Main branch + PRs from main repo only
default_conditions = ["allow_main", "allow_pull_request"]

# ✅ Alternative - Environment-based deployments
default_conditions = ["allow_environment"]
github_environments = ["production", "staging"]
```

## Manage roles for a repo
- **allow_all**: ⚠️ **DEPRECATED** - Blocked due to critical security vulnerability. Use specific conditions instead.
- **allow_main** : Allow GitHub Actions only running on the main branch.
- **allow_pull_request**: Allow assuming the role for a pull request.
- **allow_environment**: Allow GitHub Actions only for environments, by setting github_environments you can limit to a dedicated environment.
- **deny_pull_request**: Denies assuming the role for a pull request.

**Security Best Practice**: Always use the principle of least privilege. Only grant access to specific branches, environments, or events that genuinely need AWS access.

## Security Best Practices

### Understanding the allow_all Vulnerability

The `allow_all` condition created a **critical security vulnerability** that allowed unauthorized AWS access through forked repositories. Here's why it was dangerous:

**The Problem:**
- The `allow_all` implementation used the OIDC claim pattern: `repo:<org>/<repo>:*`
- The `*` wildcard matched **ALL** GitHub OIDC sub-claims, including:
  - `repo:myorg/myrepo:ref:refs/heads/main` ✓ (intended)
  - `repo:myorg/myrepo:pull_request` ✓ (intended for some workflows)
  - `repo:myorg/myrepo:environment:production` ✓ (intended)
  - `repo:myorg/myrepo:pull_request` **from forked repositories** ⚠️ (UNINTENDED!)

**Attack Scenario:**
1. Attacker forks your public repository
2. Attacker modifies GitHub Actions workflow in their fork to exfiltrate credentials or access AWS resources
3. When the workflow runs, GitHub issues an OIDC token with `sub` claim: `repo:myorg/myrepo:pull_request`
4. Your AWS IAM role accepts this token because it matches `repo:myorg/myrepo:*`
5. Attacker now has full access to your AWS resources via the assumed role

**Impact:**
- Data exfiltration from S3 buckets, databases, or other AWS services
- Resource manipulation (EC2, Lambda, etc.)
- Cost inflation through resource creation
- Supply chain attacks through deployment pipeline compromise

### Recommended Secure Configurations

Choose the configuration that best matches your workflow requirements:

#### 1. Main Branch Only (Most Secure)
**Use case**: Production deployments from main/master branch only

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "myorg/myrepo"
  
  default_conditions = ["allow_main", "deny_pull_request"]
}
```

**Why this is secure:**
- Only commits merged to main branch can assume the role
- Pull requests (including from forks) are explicitly denied
- Provides clear separation between testing and production

#### 2. Main Branch + Pull Requests from Main Repository
**Use case**: Testing AWS integrations in PRs from trusted contributors

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "myorg/myrepo"
  
  default_conditions = ["allow_main", "allow_pull_request"]
}
```

**Why this is secure:**
- `allow_pull_request` only allows PRs from the **main repository**, not forks
- Maintains protection against forked repository attacks
- Enables pre-merge testing in a controlled environment

**Note**: This still allows any branch in your main repository to trigger workflows. Ensure branch protection rules are in place.

#### 3. Environment-Based Deployments (Most Flexible)
**Use case**: Multiple deployment stages with GitHub Environments

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "myorg/myrepo"
  
  default_conditions  = ["allow_environment"]
  github_environments = ["production", "staging"]
}
```

**Why this is secure:**
- Leverages GitHub Environment protection rules (required reviewers, wait timers)
- Provides granular control over which workflows can deploy
- Supports multiple environments with different security requirements

### Using deny_pull_request

The `deny_pull_request` condition provides an **additional layer of defense** by explicitly blocking pull request workflows from assuming the role.

**When to use:**
- ✅ Production roles that should only be accessible from main branch
- ✅ Roles with sensitive permissions (write access to databases, S3 buckets)
- ✅ When you want defense-in-depth (combine with `allow_main`)

**How it works:**
```hcl
default_conditions = ["allow_main", "deny_pull_request"]
```

This configuration:
1. **Allows** workflows running on the main branch via `allow_main`
2. **Denies** any workflow triggered by a pull request via `deny_pull_request`
3. The `deny_pull_request` acts as a safety net even if `allow_main` has unexpected behavior

**Workflow evaluation:**
- Main branch push: ✅ Allowed (matches `allow_main`, not blocked by `deny_pull_request`)
- Pull request from main repo: ❌ Denied (blocked by `deny_pull_request`)
- Pull request from fork: ❌ Denied (blocked by `deny_pull_request`)
- Tag/release: ❌ Denied (doesn't match `allow_main`)

**Best Practice**: Always include `deny_pull_request` when using `allow_main` for production roles. This provides defense-in-depth and makes your security intent explicit.

### Additional Security Recommendations

1. **Use Separate Roles**: Create different IAM roles for different environments/workflows
   ```hcl
   # Production role - strict controls
   module "gh_openid_prod" {
     source             = "github.com/norbybaru/terraform-aws-openid-github"
     repo               = "myorg/myrepo"
     role_name          = "github-actions-prod"
     default_conditions = ["allow_main", "deny_pull_request"]
   }
   
   # Development role - more permissive for testing
   module "gh_openid_dev" {
     source             = "github.com/norbybaru/terraform-aws-openid-github"
     repo               = "myorg/myrepo"
     role_name          = "github-actions-dev"
     default_conditions = ["allow_main", "allow_pull_request"]
   }
   ```

2. **Scope IAM Permissions**: Use least-privilege IAM policies on the assumed role
   ```hcl
   # Good: Specific resources and actions
   data "aws_iam_policy_document" "limited" {
     statement {
       actions   = ["s3:PutObject", "s3:GetObject"]
       resources = ["arn:aws:s3:::my-specific-bucket/*"]
     }
   }
   
   # Bad: Overly broad permissions
   data "aws_iam_policy_document" "too_broad" {
     statement {
       actions   = ["s3:*"]
       resources = ["*"]
     }
   }
   ```

3. **Monitor and Audit**: Enable CloudTrail logging for role assumption events
   ```hcl
   # Monitor who is assuming your GitHub Actions role
   resource "aws_cloudwatch_log_metric_filter" "github_assume_role" {
     name           = "github-actions-assume-role"
     log_group_name = "/aws/cloudtrail/my-trail"
     pattern        = "{ $.eventName = \"AssumeRoleWithWebIdentity\" && $.requestParameters.roleArn = \"${module.gh_openid.role.arn}\" }"
   }
   ```

4. **Use Session Tags**: Leverage OIDC claims for fine-grained access control
   ```hcl
   additional_conditions = [
     {
       test     = "StringLike"
       variable = "token.actions.githubusercontent.com:sub"
       values   = ["repo:myorg/myrepo:ref:refs/heads/main"]
     }
   ]
   ```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.openid_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_policy_document.openid_policy_document_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_conditions"></a> [additional\_conditions](#input\_additional\_conditions) | (Optional) Additonal conditions for checking the OIDC claim. | <pre>list(object({<br>    test     = string<br>    variable = string<br>    values   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | A list of client IDs (also known as audiences) | `list(string)` | <pre>[<br>  "sts.amazonaws.com"<br>]</pre> | no |
| <a name="input_default_conditions"></a> [default\_conditions](#input\_default\_conditions) | (Optional) Default condtions to apply, at least one of the following is mandatory: 'allow\_main', 'allow\_environment', 'allow\_pull\_request', and 'deny\_pull\_request'. Note: 'allow\_all' is deprecated and blocked due to security concerns. | `list(string)` | <pre>[<br>  "allow_main",<br>  "deny_pull_request"<br>]</pre> | no |
| <a name="input_github_environments"></a> [github\_environments](#input\_github\_environments) | (Optional) Allow GitHub action to deploy to all (default) or to one of the environments in the list. | `list(string)` | <pre>[<br>  "*"<br>]</pre> | no |
| <a name="input_openid_connect_provider_arn"></a> [openid\_connect\_provider\_arn](#input\_openid\_connect\_provider\_arn) | Set the openid connect provider ARN when the provider is not managed by the module. | `string` | `null` | no |
| <a name="input_provider_url"></a> [provider\_url](#input\_provider\_url) | The URL of the identity provider. Corresponds to the iss claim. | `string` | `"https://token.actions.githubusercontent.com"` | no |
| <a name="input_repo"></a> [repo](#input\_repo) | (Optional) GitHub repository to grant access to assume a role via OIDC. When the repo is set, a role will be created. | `string` | n/a | yes |
| <a name="input_role_max_session_duration"></a> [role\_max\_session\_duration](#input\_role\_max\_session\_duration) | Maximum session duration (in seconds) that you want to set for the specified role. | `number` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | (Optional) role name of the created role, if not provided the `namespace` will be used. | `string` | `null` | no |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | (Optional) Path for the created role, requires `repo` is set. | `string` | `"/github-actions/"` | no |
| <a name="input_role_permissions_boundary"></a> [role\_permissions\_boundary](#input\_role\_permissions\_boundary) | (Optional) Boundary for the created role, requires `repo` is set. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to attach onto resources | `map(string)` | `{}` | no |
| <a name="input_thumb_prints"></a> [thumb\_prints](#input\_thumb\_prints) | A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s) | `list(string)` | <pre>[<br>  "6938fd4d98bab03faadb97b34396831e3780aea1"<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditions"></a> [conditions](#output\_conditions) | The assumed repository conditions added to the role. |
| <a name="output_openid_connect_provider_arn"></a> [openid\_connect\_provider\_arn](#output\_openid\_connect\_provider\_arn) | AWS OpenID Connected identity provider arn. |
| <a name="output_assume_role"></a> [assume_role](#output\_assume_role) | The created role that can be assumed to configure the repository. |


## Usage
Usage without additional policies attached to the role
```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo = "<org>/<repo>"

  # override default conditions
  default_conditions          = ["allow_main"]
}
```

Usage with additional policies attached to the role
```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo = "<org>/<repo>"

  # override default conditions
  default_conditions          = ["allow_main"]
}

resource "aws_s3_bucket" "example" {
  bucket = "bucket-name"

  tags = {
    allow-gh-action-access = "true"
  }
}

resource "aws_iam_role_policy" "s3" {
  name   = "s3-policy"
  role   = module.gh_openid.role.name
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid = "1"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/allow-gh-action-access"
      values = ["true"]
    }
  }
}
```
