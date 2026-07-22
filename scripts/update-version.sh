#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DOCKERFILE_PATH=${DOCKERFILE_PATH:-"$ROOT_DIR/Dockerfile"}
TAILSCALE_STABLE_URL="https://pkgs.tailscale.com/stable"

require_line() {
  pattern=$1

  if [ "$(grep -c "^${pattern}" "$DOCKERFILE_PATH")" -ne 1 ]; then
    echo "Expected exactly one Dockerfile line matching: ${pattern}" >&2
    exit 1
  fi
}

latest_version() {
  curl -fsSL "${TAILSCALE_STABLE_URL}/" |
    sed -n 's/.*<option value="\([0-9][0-9.]*\)".*/\1/p' |
    sort -V |
    tail -n1
}

fetch_sha256() {
  version=$1
  arch=$2

  curl -fsSL "${TAILSCALE_STABLE_URL}/tailscale_${version}_${arch}.tgz.sha256" | tr -d '\r\n'
}

update_arg_line() {
  file_path=$1
  arg_name=$2
  arg_value=$3

  tmp_file=$(mktemp)
  sed "s|^ARG ${arg_name}=.*$|ARG ${arg_name}=${arg_value}|" "$file_path" >"$tmp_file"
  mv "$tmp_file" "$file_path"
}

if [ $# -gt 1 ]; then
  echo "Usage: $0 [version]" >&2
  exit 1
fi

if [ $# -eq 1 ]; then
  version=$1
else
  version=$(latest_version)
fi

if [ -z "$version" ]; then
  echo "Failed to determine Tailscale version" >&2
  exit 1
fi

amd64_sha=$(fetch_sha256 "$version" amd64)
arm64_sha=$(fetch_sha256 "$version" arm64)

if [ -z "$amd64_sha" ] || [ -z "$arm64_sha" ]; then
  echo "Failed to fetch required checksums for version $version" >&2
  exit 1
fi

require_line 'ARG VERSION='
require_line 'ARG TAILSCALE_SHA256_AMD64='
require_line 'ARG TAILSCALE_SHA256_ARM64='

update_arg_line "$DOCKERFILE_PATH" VERSION "$version"
update_arg_line "$DOCKERFILE_PATH" TAILSCALE_SHA256_AMD64 "$amd64_sha"
update_arg_line "$DOCKERFILE_PATH" TAILSCALE_SHA256_ARM64 "$arm64_sha"

echo "Updated $DOCKERFILE_PATH to Tailscale $version"
