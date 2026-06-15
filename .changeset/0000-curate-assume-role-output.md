---
"terraform-aws-openid-github": minor
---

The `assume_role` output now returns a curated object (`arn`, `name`, `id`, `unique_id`, `path`, `permissions_boundary`, `assume_role_policy`, `max_session_duration`, `tags_all`) instead of the full `aws_iam_role` resource. This removes the "Deprecated value used" warning that surfaced under AWS provider 5.100+ because the full object carried the provider-deprecated `inline_policy` attribute. Common usages (`assume_role.name`, `assume_role.arn`) are unchanged.
