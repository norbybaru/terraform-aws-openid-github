variable "additional_conditions" {
  description = "(Optional) Additonal conditions for checking the OIDC claim."
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
}

variable "client_id" {
  type        = list(string)
  description = "A list of client IDs (also known as audiences)"
  default     = ["sts.amazonaws.com"]
}

variable "default_conditions" {
  description = "(Optional) Default condtions to apply, at least one of the following is mandatory: 'allow_main', 'allow_environment', 'allow_pull_request', 'allow_all' and 'deny_pull_request'."
  type        = list(string)
  default     = ["allow_main", "deny_pull_request"]
  validation {
    condition     = length(setintersection(var.default_conditions, ["allow_main", "allow_environment", "deny_pull_request", "allow_all", "allow_pull_request"])) != length(var.default_conditions)
    error_message = "Valid configurations are: 'allow_main', 'allow_environment', 'allow_pull_request', 'allow_all' and 'deny_pull_request'."
  }
  validation {
    condition     = length(var.default_conditions) == 0
    error_message = "At least one of the following configuration needs to be set: 'allow_main', 'allow_environment', 'allow_pull_request', 'allow_all' and 'deny_pull_request'."
  }
}

variable "github_environments" {
  description = "(Optional) Allow GitHub action to deploy to all (default) or to one of the environments in the list."
  type        = list(string)
  default     = ["*"]
}

variable "provider_url" {
  type        = string
  description = "The URL of the identity provider. Corresponds to the iss claim."
  default     = "https://token.actions.githubusercontent.com"
}

variable "repo" {
  description = "(Optional) GitHub repository to grant access to assume a role via OIDC. When the repo is set, a role will be created."
  type        = string
  validation {
    condition     = var.repo == null || can(regex("^.+\\/.+", var.repo))
    error_message = "Repo name is not matching the pattern <owner>/<repo>."
  }
  validation {
    condition     = var.repo == null || !can(regex("^.*\\*.*$", var.repo))
    error_message = "Wildcards are not allowed."
  }
}

variable "role_max_session_duration" {
  description = "Maximum session duration (in seconds) that you want to set for the specified role."
  type        = number
  default     = null
}

variable "role_path" {
  description = "(Optional) Path for the created role, requires `repo` is set."
  type        = string
  default     = "/github-actions/"
}

variable "role_permissions_boundary" {
  description = "(Optional) Boundary for the created role, requires `repo` is set."
  type        = string
  default     = null
}

variable "thumb_prints" {
  type        = list(string)
  description = "A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)"
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}