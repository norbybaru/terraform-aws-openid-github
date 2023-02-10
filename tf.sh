#!/usr/bin/env bash

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python3 -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

terraform_version="$(<${__DIR__}/.terraform-version)"
aws_profile="default"

# envwars
export TF_IN_AUTOMATION="true"

target_init() {
  terraform init -upgrade=true
}

target_plan() {
  terraform get
  terraform plan -out output.plan
}

target_apply() {
  terraform show output.plan
  terraform apply output.plan

  #rm "${ENV}.plan"
}

target_destroy() {
  terraform destroy
}

target_state() {
  terraform state "${@}"
}

install_terraform() {
  local kernel_name arch zip_file target_bin
  if ! terraform --version | grep -qF "Terraform v${terraform_version}"; then
    consolelog "Installing terraform v${terraform_version}..."
    kernel_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(current_arch)"

    zip_file="terraform_${terraform_version}_${kernel_name}_${arch}.zip"

    curl -#LO "https://releases.hashicorp.com/terraform/${terraform_version}/${zip_file}"

    target_bin="/usr/local/bin/terraform"
    if [[ ! -w "${target_bin:?}" ]]; then
      sudo touch "${target_bin:?}"
      sudo chown "${USER}" "${target_bin:?}"
    fi

    unzip -qop "${zip_file}" > "${target_bin:?}"
    chmod +x "${target_bin:?}"
    rm -f "${zip_file}"
  else
    consolelog "Found terraform v${terraform_version}" success
  fi
}

target="target_${1}"
if [[ "$(type -t "${target}")" != "function" ]]; then
  echo "unknown target: ${target#*_}" "error"

  echo -e "\n\nAvailable targets:"
  targets=( $(compgen -A function) )
  for target in "${targets[@]}"; do
    if [[ "${target}" == "target_"* ]]; then
      echo "- ${target#*_}"
    fi
  done

  exit 1
fi

"${target}" "${@}"