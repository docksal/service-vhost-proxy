# Virtual host proxy Docker image for Docksal

Automated HTTP/HTTPS virtual host proxy and container supervisor for Docksal.

This image(s) is part of the [Docksal](http://docksal.io) image library.

## Features

- HTTP/HTTPS and HTTP/2 virtual host routing
- Supports Docker Compose based stacks as well as standalone containers (`docker run ...`)
- On-demand stack starting (upon HTTP/HTTPS request)
- Stack stopping after a given period of inactivity
- Stack cleanup after a given period of inactivity

On-demand start and inactivity stop/cleanup features are the key components used by [Docksal Sandbox Server](https://github.com/docksal/sandbox-server). 

## Usage

Start the proxy container:

```bash
docker run -d --name docksal-vhost-proxy --label "io.docksal.group=system" --restart=always --privileged --userns=host \
    -p "${DOCKSAL_VHOST_PROXY_PORT_HTTP:-80}":80 -p "${DOCKSAL_VHOST_PROXY_PORT_HTTPS:-443}":443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    docksal/vhost-proxy
```

## Container configuration 

Proxy reads routing settings from container labels. 

`io.docksal.virtual-host`

Virtual host mapping. Supports any domain (but does not handle DNS), multiple values separated by commas, wildcard 
sub-domains.

Example: `io.docksal.virtual-host=example1.com,*.example2.com`


`io.docksal.virtual-port`

Virtual port mapping. Useful when a container exposes an non-default HTTP port (other than port `80`).
Only supports HTTP target services, single value.  

Example: `io.docksal.virtual-port=3000`

### Example: Routing to a standalone container

Routing `http(s)://myapp.example.com` to a standalone container listening on port `2580` (HTTP).

```bash
# Start a standalone container
$ docker run -d --name=http-echo \
	--label=io.docksal.virtual-host=myapp.example.com \
	--label=io.docksal.virtual-port=2580 \
	--expose 2580 \
	hashicorp/http-echo:0.2.3 -listen=:2580 -text="Hello world: standalone"

# Verify
$ DOCKER_HOST=192.168.64.100
$ curl --header "Host: myapp.example.com" http://${DOCKER_HOST}
Hello world: standalone
``` 

### Example: Routing to a container in a Docker Compose project stack

Routing `http(s)://myproject.example.com` to a container in a Docker Compose stack listening on port `2580` (HTTP).

```bash
$ cat docker-compose.yaml
version: "3"

# Uncomment if you want this stack to attach to an existing network (e.g., another Docksal project network)
#networks:
#  default:
#    external: true
#    name: <project-name>_default

services:
  web:
    image: hashicorp/http-echo:0.2.3
    # Comment out if using a specific existing network
    network_mode: bridge # Use the default shared 'bridge' network
    expose:
      - 2580
    labels:
      - "io.docksal.virtual-host=myproject.docksal.site"
      - "io.docksal.virtual-port=2580"
    command: ['-listen=:2580', '-text="Hello world: docker-compose"']

$ docker-compose -p myproject up -d
...

# Verify
$ curl http://myproject.docksal.site
"Hello world: docker-compose"
``` 

Notice that we used `myproject.docksal.site` in this example and did not project the `Host` header in the curl command.
`*.docksal.site` domains are automatically resolved to `192.168.64.100` (Docksal's canonical IP address).

You can use an arbitrary domain, but then you'll have to handle the DNS for that domain.

## Advanced proxy configuration

These advanced settings can be used in CI sandbox environments and help keep the resource usage down by stopping 
Docksal project containers after a period of inactivity.

Projects are automatically restarted upon a new HTTP request (unless `PROJECT_AUTOSTART` is set to `0`, see below).

See [Docksal Sandbox Server](https://github.com/docksal/sandbox-server) for the CI sandbox use case.

See [services.yml](https://github.com/docksal/docksal/blob/develop/stacks/services.yml) in the [docksal/docksal](https://github.com/docksal/docksal) 
repo for an extensive list of examples of how docksal/vhost-proxy is used in Docksal.

`PROJECT_INACTIVITY_TIMEOUT`

Defines the timeout (e.g. 0.5h) of inactivity after which the project stack will be stopped.  
This option is inactive by default (set to `0`).

`PROJECT_DANGLING_TIMEOUT`

**WARNING: This is a destructive option. Use at your own risk!**

Defines the timeout (e.g. 168h) of inactivity after which the project stack and code base will be entirely wiped out from the host.  
This option is inactive by default (set to `0`).

For the cleanup job to work, proxy needs access to the projects directory on the host.  
Create a Docker bind volume pointing to the directory where projects are stored:

```
docker volume create --name docksal_projects --opt type=none --opt device=$PROJECTS_ROOT --opt o=bind

```

then pass it using `-v docksal_projects:/projects` in `docker run` command.

Example (extra configuration in the middle): 

```bash
docker run -d --name docksal-vhost-proxy --label "io.docksal.group=system" --restart=always --privileged --userns=host \
    -p "${DOCKSAL_VHOST_PROXY_PORT_HTTP:-80}":80 -p "${DOCKSAL_VHOST_PROXY_PORT_HTTPS:-443}":443 \
    -e PROJECT_INACTIVITY_TIMEOUT="${PROJECT_INACTIVITY_TIMEOUT:-0}" \

    -e PROJECT_INACTIVITY_TIMEOUT="${PROJECT_INACTIVITY_TIMEOUT:-0}" \
    -e PROJECT_DANGLING_TIMEOUT="${PROJECT_DANGLING_TIMEOUT:-0}" \
    -v docksal_projects:/projects \
    
    -v /var/run/docker.sock:/var/run/docker.sock \
    docksal/vhost-proxy
```

`io.docksal.permanent=true`

It is possible to protect certain projects/containers from being automatically removed after `PROJECT_DANGLING_TIMEOUT`.

Projects/containers with the `io.docksal.permanent=true` label are considered permanent are skipped during the cleanup.
When running the default Docksal stack, this label can be set with `SANDBOX_PERMANENT=true` in `docksal.env` (or an 
environment specific equivalent, e.g. `docksal-ci.env`).

Note: permanent projects will still be put into hibernation according to `PROJECT_INACTIVITY_TIMEOUT`.

`PROJECT_AUTOSTART`

Setting this variable to `0` will disable autostart projects by visiting project url. This option is active by default (set to `1`).

## Default and custom certs for HTTPS

The default server cert is a self-signed cert for `*.docksal`. It allows an HTTPS connection to be established, but will 
make browsers complain that the cert is not valid. If that's not acceptable, you can use a valid custom cert. 

To use custom certs, mount a folder with certs to `/etc/certs/custom`. Certs are looked up by virtual host name. 

E.g., cert and key for `example.com` (or `*.example.com`) are expected in: 

```
/etc/certs/custom/example.com.crt
/etc/certs/custom/example.com.key
```

Shared certs (SNI) are also supported. Use `io.docksal.cert-name` label to set the cert name for a container.

Example: for `io.docksal.cert-name=shared` the following cert/key will be used:

```
/etc/certs/custom/shared.crt
/etc/certs/custom/shared.key
```

When multiple domain values are set in `io.docksal.virtual-host`, the first one is considered the primary one and 
used for certificate lookup. You can also always point to a specific cert with `io.docksal.cert-name`. 

When projects are (re)started over HTTPS, the default virtual host config kicks in first. It uses the default self-signed 
cert, which would trigger a browser warning, even though the actual virtual host is then served using a valid custom 
cert. To overcome this issue, you can specify the default custom cert name using the `DEFAULT_CERT` environment variable. 

You can use a single domain or a shared (SNI) cert, just like with other custom certs.

Example: `DEFAULT_CERT=example.com` or `DEFAULT_CERT=shared`  


## Logging and debugging

The following container environment variables can be used to enabled various logging options (disabled by default). 

`ACCESS_LOG` - Set to `1` to enable access logging.
`DEBUG_LOG` - Set to `1` to enable debug logging.
`STATS_LOG` - Set to `1` to enable project stats logging.

Check logs with `docker logs docksal-vhost-proxy`.


## Variable mapping for Docksal

When using this image with Docksal (99% of cases), settings for `vhost-proxy` are set via `$HOME/.docksal/docksal.env`. 

The following variable mappings should be applied:

| Configuration variable        | Variable in `$HOME/.docksal/docksal.env`  |
| ----------------------------- | ----------------------------------------  |
| `ACCESS_LOG`                  | `DOCKSAL_VHOST_PROXY_ACCESS_LOG`          |
| `DEBUG_LOG`                   | `DOCKSAL_VHOST_PROXY_DEBUG_LOG`           |
| `STATS_LOG`                   | `DOCKSAL_VHOST_PROXY_STATS_LOG`           |
| `PROJECT_INACTIVITY_TIMEOUT`  | `PROJECT_INACTIVITY_TIMEOUT`              |
| `PROJECT_DANGLING_TIMEOUT`    | `PROJECT_DANGLING_TIMEOUT`                |
| `DEFAULT_CERT`                | `DOCKSAL_VHOST_PROXY_DEFAULT_CERT`        |
