FROM alpine:3.20 as builder

ARG TARGETARCH
ARG VERSION=1.72.1

RUN apk add --no-cache curl tar && \
    curl -sL "https://pkgs.tailscale.com/stable/tailscale_${VERSION}_${TARGETARCH}.tgz" | \
    tar -zxf - -C /tmp/tailscale --strip-components=1

FROM alpine:3.20

COPY --from=builder /tmp/tailscale/tailscaled /usr/local/bin/tailscaled
COPY --from=builder /tmp/tailscale/tailscale /usr/local/bin/tailscale

RUN apk add --no-cache iptables ip6tables iproute2 ca-certificates

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]