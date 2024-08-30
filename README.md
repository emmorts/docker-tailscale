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
  -e TAILSCALE_AUTH_KEY=<your_auth_key> \
  -v /dev/net/tun:/dev/net/tun \
  --network host \
  --privileged \
  emmorts/tailscale
```


## Credits

inspired by @hamishforbes [gist](https://gist.github.com/hamishforbes/2ac7ae9d7ea47cad4e3a813c9b45c10f)
