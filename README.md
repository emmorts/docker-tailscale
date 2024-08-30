# docker-tailscale

This is a fork of [mvisonneau/docker-tailscale](https://github.com/mvisonneau/docker-tailscale). The functionality is more or less the same - the only difference is that this version has a more robust entrypoint logic, that is able to handle the case where the container is restarted or fails to start.

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
