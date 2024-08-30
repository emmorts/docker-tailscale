#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

cleanup() {
  log "Stopping Tailscale..."
  tailscale down
  kill $TAILSCALED_PID
  wait $TAILSCALED_PID
  log "Tailscale stopped"
}

up() {
  log "Starting Tailscale..."

  local retry_count=0
  local max_retries=5
  local retry_delay=5

  while [ $retry_count -lt $max_retries ]; do
    if tailscale up \
      --accept-dns="${TAILSCALE_ACCEPT_DNS:-true}" \
      --accept-routes="${TAILSCALE_ACCEPT_ROUTES:-false}" \
      --advertise-connector="${TAILSCALE_ADVERTISE_CONNECTOR:-false}" \
      --advertise-exit-node="${TAILSCALE_ADVERTISE_EXIT_NODE:-false}" \
      --advertise-routes="${TAILSCALE_ADVERTISE_ROUTES:-}" \
      --advertise-tags="${TAILSCALE_ADVERTISE_TAGS:-}" \
      --authkey="${TAILSCALE_AUTH_KEY:-}" \
      --exit-node-allow-lan-access="${TAILSCALE_EXIT_NODE_ALLOW_LAN_ACCESS:-false}" \
      --exit-node="${TAILSCALE_EXIT_NODE:-}" \
      --force-reauth="${TAILSCALE_FORCE_REAUTH:-false}" \
      --host-routes="${TAILSCALE_HOST_ROUTES:-true}" \
      --hostname="${TAILSCALE_HOSTNAME:-$(hostname)}" \
      --login-server="${TAILSCALE_LOGIN_SERVER:-https://login.tailscale.com}" \
      --netfilter-mode="${TAILSCALE_NETFILTER_MODE:-on}" \
      --qr="${TAILSCALE_QR:-false}" \
      --shields-up="${TAILSCALE_SHIELDS_UP:-false}" \
      --snat-subnet-routes="${TAILSCALE_SNAT_SUBNET_ROUTES:-true}" \
      --ssh="${TAILSCALE_SSH:-false}"; then
      log "Tailscale started successfully"
      return 0
    else
      log "Failed to start Tailscale. Retrying in $retry_delay seconds..."
      sleep $retry_delay
      ((retry_count++))
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

trap cleanup EXIT INT TERM

log "Starting tailscaled..."
tailscaled \
  -port "${TAILSCALED_PORT:-0}" \
  -socket "${TAILSCALED_SOCKET:-/var/run/tailscale/tailscaled.sock}" \
  -state "${TAILSCALED_STATE:-/var/lib/tailscale/tailscaled.state}" \
  -tun "${TAILSCALED_TUN:-tailscale0}" \
  -verbose "${TAILSCALED_VERBOSE:-0}" &

TAILSCALED_PID=$!

sleep 2
up

while true; do
  if ! kill -0 $TAILSCALED_PID 2>/dev/null; then
    log "tailscaled process died unexpectedly"
    exit 1
  fi
  sleep 60
done
