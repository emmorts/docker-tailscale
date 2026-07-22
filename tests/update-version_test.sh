#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/scripts/update-version.sh"

fail() {
  echo "not ok - $*" >&2
  exit 1
}

make_stub_curl() {
  stub_dir=$1
  state_dir=$2

  mkdir -p "$stub_dir"

  cat >"$stub_dir/curl" <<EOF
#!/bin/sh
url=\$2
printf '%s\n' "\$url" >>"$state_dir/curl.log"

case "\$url" in
  https://pkgs.tailscale.com/stable/)
    cat <<'HTML'
<html>
  <option value="1.98.4">1.98.4</option>
  <option value="1.99.1">1.99.1</option>
  <option value="1.100.0">1.100.0</option>
</html>
HTML
    ;;
  https://pkgs.tailscale.com/stable/tailscale_1.100.0_amd64.tgz.sha256)
    printf '%s\n' 'amd64-latest-sha'
    ;;
  https://pkgs.tailscale.com/stable/tailscale_1.100.0_arm64.tgz.sha256)
    printf '%s\n' 'arm64-latest-sha'
    ;;
  https://pkgs.tailscale.com/stable/tailscale_1.77.3_amd64.tgz.sha256)
    printf '%s\n' 'amd64-explicit-sha'
    ;;
  https://pkgs.tailscale.com/stable/tailscale_1.77.3_arm64.tgz.sha256)
    printf '%s\n' 'arm64-explicit-sha'
    ;;
  *)
    echo "unexpected url: \$url" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "$stub_dir/curl"
}

make_dockerfile_copy() {
  path=$1

  cat >"$path" <<'EOF'
FROM alpine:3.22 AS builder
ARG VERSION=1.98.4
ARG TAILSCALE_SHA256_AMD64=old-amd64
ARG TAILSCALE_SHA256_ARM64=old-arm64
EOF
}

test_defaults_to_latest_version() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  mkdir -p "$tmpdir/bin"
  make_stub_curl "$tmpdir/bin" "$tmpdir"
  make_dockerfile_copy "$tmpdir/Dockerfile"

  PATH="$tmpdir/bin:$PATH" DOCKERFILE_PATH="$tmpdir/Dockerfile" sh "$SCRIPT"

  grep -Fx 'ARG VERSION=1.100.0' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not update VERSION to latest stable"
  grep -Fx 'ARG TAILSCALE_SHA256_AMD64=amd64-latest-sha' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not update latest amd64 checksum"
  grep -Fx 'ARG TAILSCALE_SHA256_ARM64=arm64-latest-sha' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not update latest arm64 checksum"

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_accepts_explicit_version() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  mkdir -p "$tmpdir/bin"
  make_stub_curl "$tmpdir/bin" "$tmpdir"
  make_dockerfile_copy "$tmpdir/Dockerfile"

  PATH="$tmpdir/bin:$PATH" DOCKERFILE_PATH="$tmpdir/Dockerfile" sh "$SCRIPT" 1.77.3

  grep -Fx 'ARG VERSION=1.77.3' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not honor explicit version"
  grep -Fx 'ARG TAILSCALE_SHA256_AMD64=amd64-explicit-sha' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not update explicit amd64 checksum"
  grep -Fx 'ARG TAILSCALE_SHA256_ARM64=arm64-explicit-sha' "$tmpdir/Dockerfile" >/dev/null ||
    fail "script did not update explicit arm64 checksum"
  if grep -Fx 'https://pkgs.tailscale.com/stable/' "$tmpdir/curl.log" >/dev/null 2>&1; then
    fail "script should not fetch latest index when explicit version is provided"
  fi

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_defaults_to_latest_version
test_accepts_explicit_version

echo "ok - update-version tests passed"
