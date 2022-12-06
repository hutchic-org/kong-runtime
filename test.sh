#!/usr/bin/env bash

set -euo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export $(grep -v '^#' $SCRIPT_DIR/.env | xargs)

function test() {
    cp -R /tmp/build/* /

    /usr/local/kong/bin/openssl version     # From kong-openssl test.sh
    ls -la /usr/local/kong/lib/libyaml.so   # From kong-openssl test.sh

    /usr/local/openresty/bin/openresty -v 2>&1 | grep -q ${OPENRESTY_VERSION}
    /usr/local/openresty/bin/openresty -V 2>&1 | grep -q pcre
    /usr/local/openresty/bin/resty -e 'print(jit.version)' | grep -q 'LuaJIT[[:space:]][[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+-[[:digit:]]\{8\}'

    ls -l /usr/local/openresty/lualib/resty/websocket/*.lua
    grep _VERSION /usr/local/openresty/lualib/resty/websocket/*.lua
    luarocks --version
}

test
