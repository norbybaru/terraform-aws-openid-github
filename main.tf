resource "aws_iam_openid_connect_provider" "openid_connect" {
  count           = var.openid_connect_provider_arn != null ? 0 : 1
  url             = var.provider_url
  client_id_list  = var.client_id
  thumbprint_list = var.thumb_prints
}

data "aws_iam_policy_document" "openid_policy_document_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.openid_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    dynamic "condition" {
      for_each = local.merge_conditions

      content {
        test     = split("|", condition.value.test)[0]
        variable = split("|", condition.value.test)[1]
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "main" {
  name                 = local.role_name
  path                 = var.role_path
  permissions_boundary = var.role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.openid_policy_document_assume_role.json
  max_session_duration = var.role_max_session_duration
  tags                 = var.tags
}