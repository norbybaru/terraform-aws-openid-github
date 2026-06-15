---
"terraform-aws-openid-github": minor
---

Add `create_openid_provider` (bool) to explicitly control whether the module manages the GitHub Actions OIDC provider. Because `count` now keys off this bool, the create/reuse decision stays plan-time-known even when `openid_connect_provider_arn` is a computed value (known after apply) — fixing the "Invalid count argument" error that occurred when passing a not-yet-created provider's ARN. Backward compatible: when the bool is unset, the existing behaviour (create unless `openid_connect_provider_arn` is set) is preserved.
