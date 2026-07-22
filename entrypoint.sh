#!/bin/sh

set -eu

log() {
  echo "$(date +'%Y/%m/%d %H:%M:%S') entrypoint: $*" >&2
}

has_env() {
  var_name=$1
  eval "[ \"\${$var_name+x}\" = x ]"
}

first_set_env() {
  for var_name in "$@"; do
    if has_env "$var_name"; then
      eval "printf '%s' \"\${$var_name}\""
      return 0
    fi
  done

  return 1
}

shell_quote() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

append_word() {
  COMMAND_ARGS="${COMMAND_ARGS} $(shell_quote "$1")"
}

append_flag_equals_from_env() {
  flag_name=$1
  shift

  if flag_value=$(first_set_env "$@"); then
    append_word "${flag_name}=${flag_value}"
  fi
}

append_flag_value_from_env() {
  flag_name=$1
  shift

  if flag_value=$(first_set_env "$@"); then
    append_word "$flag_name"
    append_word "$flag_value"
  fi
}

if state_dir_value=$(first_set_env TAILSCALED_STATE_DIR TS_STATE_DIR); then
  TAILSCALED_STATE_DIR="$state_dir_value"
else
  TAILSCALED_STATE_DIR=""
fi

if socket_value=$(first_set_env TAILSCALED_SOCKET TS_SOCKET); then
  TAILSCALED_SOCKET_PATH="$socket_value"
else
  TAILSCALED_SOCKET_PATH="/var/run/tailscale/tailscaled.sock"
fi

if state_value=$(first_set_env TAILSCALED_STATE TS_STATE); then
  TAILSCALED_STATE_PATH="$state_value"
elif [ -n "$TAILSCALED_STATE_DIR" ]; then
  TAILSCALED_STATE_PATH="$TAILSCALED_STATE_DIR/tailscaled.state"
else
  TAILSCALED_STATE_PATH="/var/lib/tailscale/tailscaled.state"
fi

if tun_value=$(first_set_env TAILSCALED_TUN); then
  TAILSCALED_TUN_NAME="$tun_value"
elif userspace_value=$(first_set_env TS_USERSPACE); then
  case "$userspace_value" in
    1|true|TRUE|yes|YES|on|ON)
      TAILSCALED_TUN_NAME="userspace-networking"
      ;;
    *)
      TAILSCALED_TUN_NAME="tailscale0"
      ;;
  esac
else
  TAILSCALED_TUN_NAME="tailscale0"
fi

if ready_timeout_value=$(first_set_env TAILSCALE_READY_TIMEOUT TS_READY_TIMEOUT); then
  TAILSCALE_READY_TIMEOUT="$ready_timeout_value"
else
  TAILSCALE_READY_TIMEOUT="30"
fi

if tailscale_extra_args_value=$(first_set_env TAILSCALE_EXTRA_ARGS TS_EXTRA_ARGS); then
  TAILSCALE_EXTRA_ARGS_VALUE="$tailscale_extra_args_value"
else
  TAILSCALE_EXTRA_ARGS_VALUE=""
fi

if tailscaled_extra_args_value=$(first_set_env TAILSCALED_EXTRA_ARGS TS_TAILSCALED_EXTRA_ARGS); then
  TAILSCALED_EXTRA_ARGS_VALUE="$tailscaled_extra_args_value"
else
  TAILSCALED_EXTRA_ARGS_VALUE=""
fi

run_tailscale() {
  if [ "$TAILSCALED_SOCKET_PATH" = "/var/run/tailscale/tailscaled.sock" ]; then
    tailscale "$@"
  else
    tailscale --socket "$TAILSCALED_SOCKET_PATH" "$@"
  fi
}

wait_for_tailscaled() {
  elapsed=0

  while [ "$elapsed" -lt "$TAILSCALE_READY_TIMEOUT" ]; do
    if ! kill -0 "$TAILSCALED_PID" 2>/dev/null; then
      log "tailscaled exited before becoming ready"
      return 1
    fi

    if [ -e "$TAILSCALED_SOCKET_PATH" ]; then
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  log "Timed out waiting for tailscaled to create socket $TAILSCALED_SOCKET_PATH"
  return 1
}

cleanup() {
  status=$?
  trap - EXIT INT TERM

  log "Stopping Tailscale..."

  if [ -e "$TAILSCALED_SOCKET_PATH" ]; then
    run_tailscale down >/dev/null 2>&1 || true
  fi

  if [ -n "${TAILSCALED_PID:-}" ] && kill -0 "$TAILSCALED_PID" 2>/dev/null; then
    kill "$TAILSCALED_PID" 2>/dev/null || true
    wait "$TAILSCALED_PID" 2>/dev/null || true
  fi

  log "Tailscale stopped"
  exit "$status"
}

up() {
  log "Starting Tailscale..."

  retry_count=0
  max_retries=5
  retry_delay=5

  while [ $retry_count -lt $max_retries ]; do
    COMMAND_ARGS=""
    append_flag_equals_from_env --accept-dns TAILSCALE_ACCEPT_DNS TS_ACCEPT_DNS
    append_flag_equals_from_env --accept-routes TAILSCALE_ACCEPT_ROUTES TS_ACCEPT_ROUTES
    append_flag_equals_from_env --advertise-connector TAILSCALE_ADVERTISE_CONNECTOR TS_ADVERTISE_CONNECTOR
    append_flag_equals_from_env --advertise-exit-node TAILSCALE_ADVERTISE_EXIT_NODE TS_ADVERTISE_EXIT_NODE
    append_flag_equals_from_env --advertise-routes TAILSCALE_ADVERTISE_ROUTES TS_ROUTES
    append_flag_equals_from_env --advertise-tags TAILSCALE_ADVERTISE_TAGS TS_ADVERTISE_TAGS
    append_flag_equals_from_env --auth-key TAILSCALE_AUTH_KEY TS_AUTHKEY
    append_flag_equals_from_env --exit-node-allow-lan-access TAILSCALE_EXIT_NODE_ALLOW_LAN_ACCESS TS_EXIT_NODE_ALLOW_LAN_ACCESS
    append_flag_equals_from_env --exit-node TAILSCALE_EXIT_NODE TS_EXIT_NODE
    append_flag_equals_from_env --force-reauth TAILSCALE_FORCE_REAUTH TS_FORCE_REAUTH
    append_flag_equals_from_env --host-routes TAILSCALE_HOST_ROUTES TS_HOST_ROUTES
    append_flag_equals_from_env --hostname TAILSCALE_HOSTNAME TS_HOSTNAME
    append_flag_equals_from_env --login-server TAILSCALE_LOGIN_SERVER TS_LOGIN_SERVER
    append_flag_equals_from_env --netfilter-mode TAILSCALE_NETFILTER_MODE TS_NETFILTER_MODE
    append_flag_equals_from_env --operator TAILSCALE_OPERATOR TS_OPERATOR
    append_flag_equals_from_env --qr TAILSCALE_QR TS_QR
    append_flag_equals_from_env --report-posture TAILSCALE_REPORT_POSTURE TS_REPORT_POSTURE
    append_flag_equals_from_env --reset TAILSCALE_RESET TS_RESET
    append_flag_equals_from_env --shields-up TAILSCALE_SHIELDS_UP TS_SHIELDS_UP
    append_flag_equals_from_env --snat-subnet-routes TAILSCALE_SNAT_SUBNET_ROUTES TS_SNAT_SUBNET_ROUTES
    append_flag_equals_from_env --ssh TAILSCALE_SSH TS_SSH
    append_flag_equals_from_env --stateful-filtering TAILSCALE_STATEFUL_FILTERING TS_STATEFUL_FILTERING

    if eval "run_tailscale up${COMMAND_ARGS}${TAILSCALE_EXTRA_ARGS_VALUE:+ ${TAILSCALE_EXTRA_ARGS_VALUE}}"; then
      log "Tailscale started successfully"
      return 0
    else
      log "Failed to start Tailscale. Retrying in $retry_delay seconds..."
      sleep $retry_delay
      retry_count=$((retry_count + 1))
    fi
  done

  log "Failed to start Tailscale after $max_retries attempts"
  return 1
}

if [ ! -d /dev/net ]; then
  mkdir -p /dev/net
fi
if [ ! -e /dev/net/tun ]; then
  mknod /dev/net/tun c 10 200
fi

mkdir -p "$(dirname "$TAILSCALED_SOCKET_PATH")"
mkdir -p "$(dirname "$TAILSCALED_STATE_PATH")"
if [ -n "$TAILSCALED_STATE_DIR" ]; then
  mkdir -p "$TAILSCALED_STATE_DIR"
fi

trap cleanup EXIT INT TERM

log "Starting tailscaled..."
COMMAND_ARGS=""
append_flag_value_from_env -port TAILSCALED_PORT TS_PORT
if ! first_set_env TAILSCALED_PORT TS_PORT >/dev/null 2>&1; then
  append_word "-port"
  append_word "0"
fi
append_word "-socket"
append_word "$TAILSCALED_SOCKET_PATH"
append_word "-state"
append_word "$TAILSCALED_STATE_PATH"
append_flag_value_from_env -statedir TAILSCALED_STATE_DIR TS_STATE_DIR
append_word "-tun"
append_word "$TAILSCALED_TUN_NAME"
append_flag_value_from_env -verbose TAILSCALED_VERBOSE TS_VERBOSE
if ! first_set_env TAILSCALED_VERBOSE TS_VERBOSE >/dev/null 2>&1; then
  append_word "-verbose"
  append_word "0"
fi
append_flag_value_from_env -debug TAILSCALED_DEBUG TS_DEBUG
append_flag_value_from_env -socks5-server TAILSCALED_SOCKS5_SERVER TS_SOCKS5_SERVER
append_flag_value_from_env -outbound-http-proxy-listen TAILSCALED_OUTBOUND_HTTP_PROXY_LISTEN TS_OUTBOUND_HTTP_PROXY_LISTEN

eval "tailscaled${COMMAND_ARGS}${TAILSCALED_EXTRA_ARGS_VALUE:+ ${TAILSCALED_EXTRA_ARGS_VALUE}}" &

TAILSCALED_PID=$!

wait_for_tailscaled
up

wait "$TAILSCALED_PID"
