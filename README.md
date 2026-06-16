# Terraform GitHub Actions OpenID Connect Provider

Terraform module to set up [OpenID Connect (OIDC) authentication between GitHub Actions and AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services). It lets GitHub Actions workflows assume an AWS IAM role without long-lived access keys.

## Features

- Manages the GitHub OIDC identity provider in your AWS account, or reuses an existing one — toggle with `create_openid_provider` and supply the ARN via `openid_connect_provider_arn`.
- Creates an IAM role with an assume-role policy that validates GitHub OIDC claims.
- Restricts who can assume the role through preset and custom claim conditions (branch, pull request, environment).

## Usage

### Basic

Allow only workflows on the `main` branch to assume the role (the default; pull requests are denied):

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/<repo>"
}
```

### With an IAM policy attached

Attach least-privilege permissions to the created role:

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/<repo>"

  default_conditions = ["allow_main", "deny_pull_request"]
}

resource "aws_s3_bucket" "example" {
  bucket = "bucket-name"
}

resource "aws_iam_role_policy" "s3" {
  name   = "s3-policy"
  role   = module.gh_openid.assume_role.name
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid     = "1"
    actions = ["s3:PutObject", "s3:GetObject"]
    resources = [
      aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}/*",
    ]
  }
}
```

### Environment-based deployments

Restrict the role to specific GitHub Environments (leverages environment protection rules such as required reviewers):

```hcl
module "gh_openid" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/<repo>"

  default_conditions  = ["allow_environment"]
  github_environments = ["production", "staging"]
}
```

### Multiple repositories in one AWS account

Only one OIDC provider per URL can exist per AWS account, so when you need OIDC roles for several repositories, have **one** module instance manage the provider and the rest reuse it: set `create_openid_provider = false` and pass the ARN.

Use the `create_openid_provider` toggle rather than relying on `openid_connect_provider_arn` alone. `count` keys off the bool, so it stays resolvable at plan time even when the ARN is a computed, "known after apply" value (e.g. another module's output). Passing a computed ARN **without** the toggle fails with `Invalid count argument`.

```hcl
# This instance owns the account's OIDC provider.
module "gh_repo_a" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/repo-a"

  create_openid_provider = true # default; shown for clarity
}

# Every other instance reuses it. No depends_on needed — referencing the
# output wires the dependency, and create_openid_provider = false keeps
# count plan-time-known even though the ARN is computed.
module "gh_repo_b" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/repo-b"

  create_openid_provider      = false
  openid_connect_provider_arn = module.gh_repo_a.openid_connect_provider_arn
}
```

When the provider is managed **outside** this module — an `aws_iam_openid_connect_provider` resource in your root config, or one created in another state/account — do the same, passing that ARN:

```hcl
module "gh_repo_c" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/repo-c"

  create_openid_provider      = false
  openid_connect_provider_arn = aws_iam_openid_connect_provider.github.arn
}
```

## Condition presets

Set `default_conditions` to control which workflows can assume the role. Default: `["allow_main", "deny_pull_request"]`.

| Preset | Effect |
|---|---|
| `allow_main` | Allow workflows running on the `main` branch. |
| `allow_tag` | Allow workflows triggered by a tag push, scoped by `tag_pattern` (default `*`; set `v*` for version tags). |
| `allow_pull_request` | Allow pull requests from the main repository (not forks). |
| `allow_environment` | Allow the GitHub Environments listed in `github_environments`. |
| `deny_pull_request` | Deny any workflow triggered by a pull request. |
| `allow_all` | ⚠️ **Deprecated and blocked** — see [SECURITY.md](SECURITY.md). |

Notes:

- `allow_pull_request` is suppressed automatically when `deny_pull_request` is also set.
- Conditions sharing the same `test` + `variable` are merged into a single IAM condition with combined values.
- Add custom claim checks with `additional_conditions`.

### Release pipelines (tag-triggered workflows)

A workflow that runs on a tag push presents an OIDC `sub` of `repo:<org>/<repo>:ref:refs/tags/<tag>`, which `allow_main` does not match. Add `allow_tag` and scope it with `tag_pattern`:

```hcl
module "gh_release" {
  source = "github.com/norbybaru/terraform-aws-openid-github"
  repo   = "<org>/<repo>"

  default_conditions = ["allow_main", "allow_tag"]
  tag_pattern        = "v*" # trust version tags (e.g. v1.2.3); omit for any tag
}
```

> **Security:** Always grant the least access a workflow needs. See [SECURITY.md](SECURITY.md) for recommended configurations and the `allow_all` vulnerability.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.openid_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_policy_document.openid_policy_document_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_conditions"></a> [additional\_conditions](#input\_additional\_conditions) | (Optional) Additional conditions for checking the OIDC claim. | <pre>list(object({<br>    test     = string<br>    variable = string<br>    values   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | A list of client IDs (also known as audiences) | `list(string)` | <pre>[<br>  "sts.amazonaws.com"<br>]</pre> | no |
| <a name="input_create_openid_provider"></a> [create\_openid\_provider](#input\_create\_openid\_provider) | Whether this module manages the GitHub Actions OIDC provider. The provider is account-unique per URL, so consumers sharing an account must create it once and set this to false elsewhere, supplying the existing ARN via openid\_connect\_provider\_arn. Prefer this explicit toggle over openid\_connect\_provider\_arn alone: count keys off this bool, so it stays plan-time-known even when the ARN is computed (known after apply). When null, the legacy behaviour applies: create unless openid\_connect\_provider\_arn is set. | `bool` | `null` | no |
| <a name="input_default_conditions"></a> [default\_conditions](#input\_default\_conditions) | (Optional) Default conditions to apply, at least one of the following is mandatory: 'allow\_main', 'allow\_environment', 'allow\_pull\_request', 'allow\_tag', 'allow\_all' and 'deny\_pull\_request'. | `list(string)` | <pre>[<br>  "allow_main",<br>  "deny_pull_request"<br>]</pre> | no |
| <a name="input_github_environments"></a> [github\_environments](#input\_github\_environments) | (Optional) List of GitHub environments allowed to assume the role. Only enforced when 'allow\_environment' is included in default_conditions. | `list(string)` | `[]` | no |
| <a name="input_openid_connect_provider_arn"></a> [openid\_connect\_provider\_arn](#input\_openid\_connect\_provider\_arn) | Set the openid connect provider ARN when the provider is not managed by the module. | `string` | `null` | no |
| <a name="input_provider_url"></a> [provider\_url](#input\_provider\_url) | The URL of the identity provider. Corresponds to the iss claim. | `string` | `"https://token.actions.githubusercontent.com"` | no |
| <a name="input_repo"></a> [repo](#input\_repo) | (Optional) GitHub repository to grant access to assume a role via OIDC. Format: owner/repo. Used to generate the default role name and trust policy conditions. | `string` | n/a | yes |
| <a name="input_role_max_session_duration"></a> [role\_max\_session\_duration](#input\_role\_max\_session\_duration) | Maximum session duration (in seconds) that you want to set for the specified role. | `number` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | (Optional) Name of the IAM role to create. If not provided, defaults to the repository name (from var.repo) with slashes replaced by hyphens and '-role' appended. | `string` | `null` | no |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | (Optional) Path for the IAM role. | `string` | `"/github-actions/"` | no |
| <a name="input_role_permissions_boundary"></a> [role\_permissions\_boundary](#input\_role\_permissions\_boundary) | (Optional) ARN of the permissions boundary policy to attach to the IAM role. | `string` | `null` | no |
| <a name="input_tag_pattern"></a> [tag\_pattern](#input\_tag\_pattern) | (Optional) Tag ref pattern trusted when 'allow\_tag' is in default\_conditions. Matched as StringLike against the OIDC sub, i.e. repo:<repo>:ref:refs/tags/<tag\_pattern>. Default '*' trusts any tag; set 'v*' to scope to conventional version tags. Only enforced when 'allow\_tag' is set. | `string` | `"*"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to attach onto resources | `map(string)` | `{}` | no |
| <a name="input_thumb_prints"></a> [thumb\_prints](#input\_thumb\_prints) | A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditions"></a> [conditions](#output\_conditions) | The assumed repository conditions added to the role. |
| <a name="output_openid_connect_provider_arn"></a> [openid\_connect\_provider\_arn](#output\_openid\_connect\_provider\_arn) | AWS OpenID Connected identity provider arn. |
| <a name="output_assume_role"></a> [assume_role](#output\_assume_role) | The created IAM role that can be assumed to configure the repository. Curated attributes — avoids leaking the provider-deprecated inline\_policy carried by the full resource object. |
<!-- END_TF_DOCS -->

## Documentation

- [SECURITY.md](SECURITY.md) — security model, the `allow_all` vulnerability, recommended configurations, and OIDC thumbprints.
- [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md) — breaking changes and migration steps between versions.
- [CONTRIBUTING.md](CONTRIBUTING.md) — local development setup, commands, and CI.
