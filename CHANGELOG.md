# terraform-aws-openid-github

## 1.1.0

### Minor Changes

- Add an `allow_tag` condition preset and a `tag_pattern` variable so tag-triggered workflows (e.g. release pipelines running on `on.push.tags`) can assume the role. Their OIDC `sub` is `repo:<repo>:ref:refs/tags/<tag>`, which no existing preset matched — previously the only workaround was a hand-rolled `additional_conditions` entry. `tag_pattern` defaults to `*` (any tag); set it to `v*` to scope trust to conventional version tags. `allow_tag` merges with `allow_main` into a single `StringLike` condition on `sub`, so a role can trust the main branch and release tags at once. ([#16](https://github.com/norbybaru/terraform-aws-openid-github/pull/16))

## 1.0.0

### Minor Changes

- Add `create_openid_provider` (bool) to explicitly control whether the module manages the GitHub Actions OIDC provider. Because `count` now keys off this bool, the create/reuse decision stays plan-time-known even when `openid_connect_provider_arn` is a computed value (known after apply) — fixing the "Invalid count argument" error that occurred when passing a not-yet-created provider's ARN. Backward compatible: when the bool is unset, the existing behaviour (create unless `openid_connect_provider_arn` is set) is preserved. ([#15](https://github.com/norbybaru/terraform-aws-openid-github/pull/15))

- The `assume_role` output now returns a curated object (`arn`, `name`, `id`, `unique_id`, `path`, `permissions_boundary`, `assume_role_policy`, `max_session_duration`, `tags_all`) instead of the full `aws_iam_role` resource. This removes the "Deprecated value used" warning that surfaced under AWS provider 5.100+ because the full object carried the provider-deprecated `inline_policy` attribute. Common usages (`assume_role.name`, `assume_role.arn`) are unchanged. ([#15](https://github.com/norbybaru/terraform-aws-openid-github/pull/15))

### Patch Changes

- Refactor README to be usage-first and split security, upgrade, and contributing content into dedicated SECURITY.md, UPGRADE_GUIDE.md, and CONTRIBUTING.md files. The README now leads with usage examples and a condition-presets table, and the reference tables are managed by the terraform-docs pre-commit hook. ([#14](https://github.com/norbybaru/terraform-aws-openid-github/pull/14))
