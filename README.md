# Terraform Github Action OpenID Connect Provider
This module manages OpenID Connect (OIDC) integration between [GitHub Actions and AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

The module can manage the following:
- The OpenID Connect identity provider for GitHub in your AWS account (via a submodule).
- A role and assume role policy to check to check OIDC claims.

## Manage roles for a repo
- **allow_all**: Allow GitHub Actions for any claim for the repository. Be careful, this allows forks as well to assume the role!
- **allow_main** : Allow GitHub Actions only running on the main branch.
- **allow_pull_request**: Allow assuming the role for a pull request.
- **allow_environment**: Allow GitHub Actions only for environments, by setting github_environments you can limit to a dedicated environment.
- **deny_pull_request**: Denies assuming the role for a pull request.

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
| <a name="input_default_conditions"></a> [default\_conditions](#input\_default\_conditions) | (Optional) Default condtions to apply, at least one of the following is mandatory: 'allow\_main', 'allow\_environment', 'allow\_pull\_request', 'allow\_all' and 'deny\_pull\_request'. | `list(string)` | <pre>[<br>  "allow_main",<br>  "deny_pull_request"<br>]</pre> | no |
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
| <a name="output_role"></a> [role](#output\_role) | The created role that can be assumed to configure the repository. |


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
