#!/usr/bin/env bash

set -euo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export $(grep -v '^#' $SCRIPT_DIR/.env)

function test() {
    echo '--- testing kong runtime (openresty, luarocks) ---'
    cp -R /tmp/build/* /
    mv /tmp/build /tmp/buffer # Check we didn't link dependencies to `/tmp/build/...`

    ls -la /tmp/buffer/usr/local/openresty/bin/openresty
    /usr/local/openresty/bin/openresty -v 2>&1 | grep -q ${OPENRESTY_VERSION}
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q pcre
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q with-pcre=
    ! ldd /usr/local/openresty/nginx/sbin/nginx | grep pcre
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q lua-kong-nginx-module
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q lua-resty-lmdb
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q lua-resty-events
    #/usr/local/openresty/bin/resty -e 'print(jit.version)' | grep -q 'LuaJIT[[:space:]][[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+-[[:digit:]]\{8\}'
    ls -la /tmp/buffer/usr/local/openresty/nginx/sbin/nginx
    ls -la /tmp/buffer/usr/local/openresty/bin/resty

    ls -l /usr/local/openresty/lualib/resty/websocket/*.lua
    grep _VERSION /usr/local/openresty/lualib/resty/websocket/*.lua
    luarocks --version

    ls -la /tmp/buffer/usr/local/openresty/lualib/libatc_router.so
    ls -la /tmp/buffer/usr/local/openresty/lualib/resty/router/router.lua
    #ldd /usr/local/openresty/lualib/libatc_router.so

    mv /tmp/buffer /tmp/build
    echo '--- tested kong runtime ---'
}

test
