#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENTRYPOINT="$ROOT_DIR/entrypoint.sh"

fail() {
  echo "not ok - $*" >&2
  exit 1
}

make_stub_commands() {
  stub_dir=$1
  state_dir=$2

  mkdir -p "$stub_dir"

  cat >"$stub_dir/date" <<EOF
#!/bin/sh
echo "2026/06/12 00:00:00"
EOF

  cat >"$stub_dir/hostname" <<EOF
#!/bin/sh
echo "test-host"
EOF

  cat >"$stub_dir/mkdir" <<EOF
#!/bin/sh
exit 0
EOF

  cat >"$stub_dir/mknod" <<EOF
#!/bin/sh
exit 0
EOF

  cat >"$stub_dir/sleep" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$state_dir/sleep.log"
exit 0
EOF

  cat >"$stub_dir/kill" <<EOF
#!/bin/sh
if [ "\$1" = "-0" ]; then
  exit 1
fi
exit 0
EOF

  cat >"$stub_dir/tailscaled" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >"$state_dir/tailscaled.args"
socket_path=
while [ \$# -gt 0 ]; do
  case "\$1" in
    -socket)
      shift
      socket_path=\$1
      ;;
  esac
  shift
done
if [ -n "\$socket_path" ]; then
  mkdir -p "\$(dirname "\$socket_path")"
  : >"\$socket_path"
fi
exit 0
EOF

  cat >"$stub_dir/tailscale" <<EOF
#!/bin/sh
case "\$1" in
  up)
    shift
    printf '%s\n' "\$*" >"$state_dir/tailscale-up.args"
    exit 0
    ;;
  down)
    printf 'down %s\n' "\$*" >>"$state_dir/tailscale-down.log"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF

  chmod +x "$stub_dir"/*
}

run_entrypoint() {
  state_dir=$1
  stub_dir=$2
  shift 2

  env \
    PATH="$stub_dir:$PATH" \
    "$@" \
    sh "$ENTRYPOINT" >"$state_dir/stdout.log" 2>"$state_dir/stderr.log" || true
}

test_passes_through_extra_args() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  make_stub_commands "$tmpdir/bin" "$tmpdir"
  run_entrypoint "$tmpdir" "$tmpdir/bin" \
    TAILSCALE_EXTRA_ARGS="--report-posture --stateful-filtering=true" \
    TAILSCALED_EXTRA_ARGS="-statedir /tmp/ts-state -debug localhost:9000"

  grep -F -- "--report-posture" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TAILSCALE_EXTRA_ARGS"
  grep -F -- "-debug localhost:9000" "$tmpdir/tailscaled.args" >/dev/null ||
    fail "tailscaled missing TAILSCALED_EXTRA_ARGS"

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_avoids_fixed_startup_sleep() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  make_stub_commands "$tmpdir/bin" "$tmpdir"
  run_entrypoint "$tmpdir" "$tmpdir/bin" \
    TAILSCALE_EXTRA_ARGS="--report-posture --stateful-filtering=true" \
    TAILSCALED_EXTRA_ARGS="-statedir /tmp/ts-state -debug localhost:9000"

  if grep -Fx "2" "$tmpdir/sleep.log" >/dev/null 2>&1; then
    fail "entrypoint should not use a fixed readiness sleep"
  fi

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_avoids_polling_loop_sleep() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  make_stub_commands "$tmpdir/bin" "$tmpdir"
  run_entrypoint "$tmpdir" "$tmpdir/bin" \
    TAILSCALE_EXTRA_ARGS="--report-posture --stateful-filtering=true" \
    TAILSCALED_EXTRA_ARGS="-statedir /tmp/ts-state -debug localhost:9000"

  if grep -Fx "60" "$tmpdir/sleep.log" >/dev/null 2>&1; then
    fail "entrypoint should wait on tailscaled instead of polling"
  fi

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_supports_ts_aliases_and_minimal_up_flags() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  make_stub_commands "$tmpdir/bin" "$tmpdir"
  run_entrypoint "$tmpdir" "$tmpdir/bin" \
    TS_AUTHKEY="tskey-from-ts" \
    TS_REPORT_POSTURE="true" \
    TS_STATEFUL_FILTERING="true" \
    TS_OPERATOR="alice" \
    TS_EXTRA_ARGS="--qr" \
    TS_DEBUG="localhost:8080" \
    TS_SOCKS5_SERVER="localhost:1055" \
    TS_OUTBOUND_HTTP_PROXY_LISTEN="localhost:8081" \
    TS_STATE_DIR="/var/lib/tailscale-custom" \
    TS_TAILSCALED_EXTRA_ARGS="-cleanup=false"

  grep -F -- "--auth-key=tskey-from-ts" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TS_AUTHKEY alias"
  grep -F -- "--report-posture=true" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TS_REPORT_POSTURE alias"
  grep -F -- "--stateful-filtering=true" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TS_STATEFUL_FILTERING alias"
  grep -F -- "--operator=alice" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TS_OPERATOR alias"
  grep -F -- "--qr" "$tmpdir/tailscale-up.args" >/dev/null ||
    fail "tailscale up missing TS_EXTRA_ARGS alias"

  if grep -F -- "--login-server=" "$tmpdir/tailscale-up.args" >/dev/null 2>&1; then
    fail "tailscale up should not force login-server when unset"
  fi
  if grep -F -- "--accept-dns=" "$tmpdir/tailscale-up.args" >/dev/null 2>&1; then
    fail "tailscale up should not force accept-dns when unset"
  fi
  if grep -F -- "--hostname=" "$tmpdir/tailscale-up.args" >/dev/null 2>&1; then
    fail "tailscale up should not force hostname when unset"
  fi

  grep -F -- "-debug localhost:8080" "$tmpdir/tailscaled.args" >/dev/null ||
    fail "tailscaled missing TS_DEBUG alias"
  grep -F -- "-socks5-server localhost:1055" "$tmpdir/tailscaled.args" >/dev/null ||
    fail "tailscaled missing TS_SOCKS5_SERVER alias"
  grep -F -- "-outbound-http-proxy-listen localhost:8081" "$tmpdir/tailscaled.args" >/dev/null ||
    fail "tailscaled missing TS_OUTBOUND_HTTP_PROXY_LISTEN alias"
  grep -F -- "-statedir /var/lib/tailscale-custom" "$tmpdir/tailscaled.args" >/dev/null ||
    fail "tailscaled missing TS_STATE_DIR alias"

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
}

test_passes_through_extra_args
test_avoids_fixed_startup_sleep
test_avoids_polling_loop_sleep
test_supports_ts_aliases_and_minimal_up_flags

echo "ok - entrypoint tests passed"
