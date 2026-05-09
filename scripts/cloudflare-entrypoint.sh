#!/bin/sh
set -eu

if [ -n "${CLI_PROXY_CONFIG_B64:-}" ]; then
  tmp_config="/CLIProxyAPI/config.yaml.tmp"
  printf '%s' "${CLI_PROXY_CONFIG_B64}" | base64 -d > "${tmp_config}"
  mv "${tmp_config}" /CLIProxyAPI/config.yaml
  chmod 600 /CLIProxyAPI/config.yaml
fi

exec /CLIProxyAPI/CLIProxyAPI
