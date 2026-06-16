# Coverage for the default_conditions presets, focused on allow_tag.
#
# Asserts against output.conditions (= local.merge_conditions), which is
# derived purely from the input locals — independent of the mocked policy
# document — so command = plan is sufficient and no AWS calls are made.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  repo = "norbybaru/example"
}

# allow_tag with the default pattern trusts any tag ref.
run "allow_tag_default_pattern_any_tag" {
  command = plan

  variables {
    default_conditions = ["allow_tag"]
  }

  assert {
    condition = anytrue([
      for c in output.conditions : contains(c.values, "repo:norbybaru/example:ref:refs/tags/*")
    ])
    error_message = "allow_tag should trust refs/tags/* by default."
  }
}

# allow_tag honours tag_pattern, scoping to version tags.
run "allow_tag_respects_tag_pattern" {
  command = plan

  variables {
    default_conditions = ["allow_tag"]
    tag_pattern        = "v*"
  }

  assert {
    condition = anytrue([
      for c in output.conditions : contains(c.values, "repo:norbybaru/example:ref:refs/tags/v*")
    ])
    error_message = "allow_tag should use tag_pattern (refs/tags/v*) when set."
  }
}

# The db-downstream case: allow_main + allow_tag merge into a single
# StringLike-on-sub condition that ORs the branch and tag refs.
run "allow_main_and_tag_merge_into_one_condition" {
  command = plan

  variables {
    default_conditions = ["allow_main", "allow_tag"]
    tag_pattern        = "v*"
  }

  # Exactly one StringLike|sub condition, carrying both refs.
  assert {
    condition = length([
      for c in output.conditions : c
      if c.test == "StringLike|token.actions.githubusercontent.com:sub"
    ]) == 1
    error_message = "allow_main and allow_tag must merge into one StringLike sub condition."
  }

  assert {
    condition = alltrue([
      for c in output.conditions : (
        contains(c.values, "repo:norbybaru/example:ref:refs/heads/main") &&
        contains(c.values, "repo:norbybaru/example:ref:refs/tags/v*")
      )
      if c.test == "StringLike|token.actions.githubusercontent.com:sub"
    ])
    error_message = "Merged condition must permit both refs/heads/main and refs/tags/v*."
  }
}

# allow_tag is not emitted when it is not requested (no tag trust by default).
run "no_tag_condition_when_not_requested" {
  command = plan

  variables {
    default_conditions = ["allow_main"]
  }

  assert {
    condition = alltrue([
      for c in output.conditions : !anytrue([
        for v in c.values : can(regex("refs/tags/", v))
      ])
    ])
    error_message = "No tag ref should be trusted unless allow_tag is requested."
  }
}

# Invalid preset names are still rejected by the validation (guards the
# updated allowed-set list).
run "invalid_condition_rejected" {
  command = plan

  variables {
    default_conditions = ["allow_tags"] # typo: not a valid preset
  }

  expect_failures = [var.default_conditions]
}
