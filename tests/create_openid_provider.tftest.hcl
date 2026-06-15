# Regression coverage for the create_openid_provider toggle.
#
# The original bug: count = (openid_connect_provider_arn != null ? 0 : 1)
# failed with "Invalid count argument" whenever the ARN was computed (known
# after apply), because count must be resolvable at plan time. The explicit
# bool toggle keeps count plan-time-known regardless of the ARN's value.
#
# mock_provider => no AWS credentials or API calls; runs free in CI.

mock_provider "aws" {
  # aws_iam_role.assume_role_policy validates its input as JSON, so the mocked
  # policy-document data source must return valid JSON rather than a generated
  # placeholder string.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  repo = "norbybaru/example"
}

# The fix: toggle off + supplied ARN resolves count at plan time (this is the
# exact shape that previously raised "Invalid count argument").
run "reuse_existing_provider_when_toggle_false" {
  command = plan

  variables {
    create_openid_provider      = false
    openid_connect_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.openid_connect) == 0
    error_message = "Expected no OIDC provider when create_openid_provider = false."
  }
}

# Toggle on => module creates the provider regardless of any ARN noise.
run "creates_provider_when_toggle_true" {
  command = plan

  variables {
    create_openid_provider = true
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.openid_connect) == 1
    error_message = "Expected the module to create the OIDC provider when create_openid_provider = true."
  }
}

# Default (toggle unset) => create the provider, preserving legacy behaviour.
run "creates_provider_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_openid_connect_provider.openid_connect) == 1
    error_message = "Expected the module to create the OIDC provider by default."
  }
}

# Backward compatibility: legacy path (no toggle) with a known ARN still skips
# creation, exactly as before this change.
run "legacy_arn_skips_creation" {
  command = plan

  variables {
    openid_connect_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.openid_connect) == 0
    error_message = "Legacy behaviour broken: supplying an ARN should skip provider creation."
  }
}

# End-to-end multi-module pattern (the README example): repo_b reuses repo_a's
# computed OIDC provider ARN. Planning this at all is the regression guard —
# feeding a computed ARN into count previously raised "Invalid count argument".
run "multiple_repos_example_plans" {
  command = plan

  module {
    source = "./examples/multiple-repos"
  }

  assert {
    condition     = output.repo_b_role_name == "example-org-repo-b-role"
    error_message = "Expected repo-b role to plan with a name derived from its repo."
  }
}
