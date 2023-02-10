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


