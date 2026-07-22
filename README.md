# docker-tailscale

This is a fork of [mvisonneau/docker-tailscale](https://github.com/mvisonneau/docker-tailscale). 

Since this is a very simple image, the only changes from the original repository are the following:
- Retry logic for `tailscale up` in case of initial failure
- Proper signal handling to ensure clean shutdown
- Cleanup function to gracefully stop Tailscale on termination

## Usage

### Docker

```bash
docker run -d \
  --name tailscale \
  -e TS_AUTHKEY=<your_auth_key> \
  -v tailscale-state:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --network host \
  --privileged \
  emmorts/tailscale
```

Persist `/var/lib/tailscale` unless you explicitly want ephemeral behavior. Without a persistent state directory, the container can require re-authentication or register as a fresh node after restart.

### Extra arguments

Use the pass-through environment variables when you need Tailscale flags that are not modeled directly by this image:

```bash
docker run -d \
  -e TS_AUTHKEY=<your_auth_key> \
  -e TS_EXTRA_ARGS="--qr" \
  -e TS_TAILSCALED_EXTRA_ARGS="-cleanup=false" \
  -v tailscale-state:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --network host \
  --privileged \
  emmorts/tailscale
```

`TS_EXTRA_ARGS` is appended to `tailscale up`. `TS_TAILSCALED_EXTRA_ARGS` is appended to `tailscaled`.

### Configuration

This image now prefers the official `TS_*` environment variable names used by Tailscale's container documentation. The legacy `TAILSCALE_*` and `TAILSCALED_*` names remain supported as aliases.

`tailscale up` is now explicit-only: flags are only passed when you set the corresponding environment variable. That avoids unintentionally resetting or overriding existing node settings on every container start.

Common `tailscale up` settings:

```bash
-e TS_AUTHKEY=<your_auth_key>
-e TS_ACCEPT_DNS=true
-e TS_ACCEPT_ROUTES=true
-e TS_HOSTNAME=my-node
-e TS_ROUTES=10.0.0.0/24,10.1.0.0/24
-e TS_OPERATOR=tailscale
-e TS_REPORT_POSTURE=true
-e TS_STATEFUL_FILTERING=true
-e TS_RESET=true
```

Common `tailscaled` settings:

```bash
-e TS_SOCKET=/var/run/tailscale/tailscaled.sock
-e TS_STATE_DIR=/var/lib/tailscale
-e TS_DEBUG=localhost:9000
-e TS_SOCKS5_SERVER=localhost:1055
-e TS_OUTBOUND_HTTP_PROXY_LISTEN=localhost:8081
```

## Maintenance

Update the pinned Tailscale version and checksums with:

```bash
scripts/update-version.sh
```

To pin an explicit version instead of the latest stable release:

```bash
scripts/update-version.sh 1.98.4
```


## Credits

inspired by @hamishforbes [gist](https://gist.github.com/hamishforbes/2ac7ae9d7ea47cad4e3a813c9b45c10f)
