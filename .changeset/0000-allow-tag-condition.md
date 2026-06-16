---
"terraform-aws-openid-github": minor
---

Add an `allow_tag` condition preset and a `tag_pattern` variable so tag-triggered workflows (e.g. release pipelines running on `on.push.tags`) can assume the role. Their OIDC `sub` is `repo:<repo>:ref:refs/tags/<tag>`, which no existing preset matched — previously the only workaround was a hand-rolled `additional_conditions` entry. `tag_pattern` defaults to `*` (any tag); set it to `v*` to scope trust to conventional version tags. `allow_tag` merges with `allow_main` into a single `StringLike` condition on `sub`, so a role can trust the main branch and release tags at once.
