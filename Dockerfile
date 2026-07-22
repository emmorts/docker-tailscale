FROM alpine:3.22@sha256:310c62b5e7ca5b08167e4384c68db0fd2905dd9c7493756d356e893909057601 AS builder

ARG TARGETARCH
ARG VERSION=1.98.9
ARG TAILSCALE_SHA256_AMD64=e6c08a8ee7e63e69aaf1b62ecd12672b3883fbcd2a176bf6cfa42a15fdce0b6b
ARG TAILSCALE_SHA256_ARM64=3cb068eb1368b6bb218d0ef0aa0a7a679a7156b7c979e2279cc2c2321b5f05c7

RUN --mount=type=cache,target=/var/cache/apk \
    set -ex; \
    apk add --no-cache curl tar && \
    mkdir -p /tmp/tailscale && \
    case "${TARGETARCH}" in \
      amd64) tailscale_sha256="${TAILSCALE_SHA256_AMD64}" ;; \
      arm64) tailscale_sha256="${TAILSCALE_SHA256_ARM64}" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    echo "Downloading Tailscale version ${VERSION} for architecture ${TARGETARCH}" && \
    curl -sSL --fail "https://pkgs.tailscale.com/stable/tailscale_${VERSION}_${TARGETARCH}.tgz" -o /tmp/tailscale.tgz && \
    echo "${tailscale_sha256}  /tmp/tailscale.tgz" | sha256sum -c - && \
    echo "Extracting Tailscale archive" && \
    tar -xzf /tmp/tailscale.tgz -C /tmp/tailscale --strip-components=1 && \
    echo "Verifying extracted files" && \
    ls -la /tmp/tailscale && \
    [ -f /tmp/tailscale/tailscaled ] && [ -f /tmp/tailscale/tailscale ] && \
    echo "Tailscale binaries successfully extracted"

FROM alpine:3.22@sha256:310c62b5e7ca5b08167e4384c68db0fd2905dd9c7493756d356e893909057601

COPY --from=builder /tmp/tailscale/tailscaled /usr/local/bin/tailscaled
COPY --from=builder /tmp/tailscale/tailscale /usr/local/bin/tailscale

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
        ca-certificates \
        iptables \
        ip6tables \
        iproute2

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
