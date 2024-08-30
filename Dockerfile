FROM alpine:3.20 AS builder

ARG TARGETARCH
ARG VERSION=1.72.1

RUN set -ex; \
    apk add --no-cache curl tar && \
    mkdir -p /tmp/tailscale && \
    echo "Downloading Tailscale version ${VERSION} for architecture ${TARGETARCH}" && \
    curl -sSL --fail "https://pkgs.tailscale.com/stable/tailscale_${VERSION}_${TARGETARCH}.tgz" -o /tmp/tailscale.tgz && \
    echo "Extracting Tailscale archive" && \
    tar -xzf /tmp/tailscale.tgz -C /tmp/tailscale --strip-components=1 && \
    echo "Verifying extracted files" && \
    ls -la /tmp/tailscale && \
    [ -f /tmp/tailscale/tailscaled ] && [ -f /tmp/tailscale/tailscale ] && \
    echo "Tailscale binaries successfully extracted"

FROM alpine:3.20

COPY --from=builder /tmp/tailscale/tailscaled /usr/local/bin/tailscaled
COPY --from=builder /tmp/tailscale/tailscale /usr/local/bin/tailscale

RUN apk add --no-cache iptables ip6tables iproute2 ca-certificates

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]