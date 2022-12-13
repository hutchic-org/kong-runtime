# Kong-OpenSSL

This repository provides pre-built kong runtime artifacts for use by Kong Gateway.

## Getting Started

### Updating the Versions

All software versions are pinned in the `.env` file

### Using

Use the most recent artifact that matches your CPU architecutre and OSTYPE
from the [Releases](https://github.com/hutchic-org/kong-runtime/releases) page or
alternatively a docker image from the [packages](https://github.com/hutchic-org/kong-runtime/pkgs/container/kong-runtime)
page.

For example
```
#!/usr/bin/env bash

arch=$(uname -m)

KONG_RUNTIME_VER="${KONG_RUNTIME_VER:-1.1.0}"
package_architecture=x86_64
if [ "$(arch)" == "aarch64" ]; then
    package_architecture=aarch64
fi
curl --fail -sSLo kong-runtime.tar.gz https://github.com/hutchic-org/kong-runtime/releases/download/$KONG_RUNTIME_VER/$package_architecture-$OSTYPE.tar.gz
tar -C /tmp/build -xvf kong-runtime.tar.gz
```

The gcr.io docker tag naming setup is:
```
ghcr.io/hutchic-org/kong-runtime:${GITHUB_RELEASE}-${OSTYPE}
# Example gcr.io/hutchic-org/kong-runtime:1.1.4-linux-musl which is a multi-architecture image

ghcr.io/hutchic-org/kong-runtime:${GITHUB_RELEASE}-${ARCHITECTURE}-${OSTYPE}
# Example gcr.io/hutchic-org/kong-runtime:1.1.0-aarch64-linux-musl

ghcr.io/hutchic-org/kong-runtime:${GIT_SHA}-${ARCHITECTURE}-${OSTYPE}
# Example kong-runtime:sha-17a5f5f-aarch64-linux-gnu
```

### Building

Prerequisites:

- make
- docker w\ buildkit

```
# Set desired environment variables. If not set the below are the defaults when this document was written
ARCHITECTURE=x86_64
OSTYPE=linux-gnu

make build/package
```
Will result in a local docker image and the build result in the `package` directory


The same result without `make`

```
ARCHITECTURE=x86_64
OSTYPE=linux-gnu

docker buildx build \
    --build-arg ARCHITECTURE=$(ARCHITECTURE) \
    --build-arg OSTYPE=$(OSTYPE) \
    --target=package \
    -o package .
```


A **similar** result without `docker`

```
ARCHITECTURE=x86_64
OSTYPE=linux-gnu

./build.sh

ls -la /tmp/build
```
*This will use your local compiler / linker so the result will not be
equivalent to a docker build and there's a strong chance the result will
not be compatible with all platforms we target for release*
