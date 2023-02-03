#!/usr/bin/env bash

set -eo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export $(grep -v '^#' $SCRIPT_DIR/.env | xargs)

function main() {
    echo '--- installing kong runtime ---'
    echo '--- downloading components ---'
    with_backoff curl --fail -sSLo pcre.tar.gz "https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz"
    tar -xzvf pcre.tar.gz
    ln -s pcre-${PCRE_VERSION} pcre

    with_backoff curl --fail -sSLo openresty.tar.gz "https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz"
    tar -xzvf openresty.tar.gz
    ln -s openresty-${OPENRESTY_VERSION} openresty

    with_backoff curl --fail -sSLo luarocks.tar.gz "https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz"
    tar -xzvf luarocks.tar.gz
    ln -s luarocks-${LUAROCKS_VERSION} luarocks

    echo '--- components downloaded ---'
    echo '--- patching openresty ---'
    pushd openresty-${OPENRESTY_VERSION}
        for patch_file in $(ls /tmp/patches/*.patch); do
            patch -p1 < $patch_file
        done

        lj_dir=$(ls -d bundle/LuaJIT*)
        lj_release_date=$(echo ${lj_dir} | sed -e 's/LuaJIT-[[:digit:]]\+.[[:digit:]]\+-\([[:digit:]]\+\)/\1/')
        lj_version_tag="LuaJIT\ 2.1.0-${lj_release_date}"
    popd
    echo '--- patched openresty ---'

    pushd openresty-${OPENRESTY_VERSION}
        echo '--- installing openresty ---'
        OPENRESTY_OPTS=(
            "--prefix=/usr/local/openresty"
            "--with-pcre-jit"
            "--with-http_ssl_module"
            "--with-http_sub_module"
            "--with-http_realip_module"
            "--with-http_stub_status_module"
            "--with-http_v2_module"
            "--without-http_encrypted_session_module"
            "--with-luajit-xcflags='-DLUAJIT_VERSION=\\\"${lj_version_tag}\\\"'"
            "-j2"
        )

        OPENRESTY_OPTS+=("--add-module=/tmp/lua-kong-nginx-module")
        OPENRESTY_OPTS+=("--add-module=/tmp/lua-kong-nginx-module/stream")
        OPENRESTY_OPTS+=("--add-module=/tmp/lua-resty-lmdb")
        OPENRESTY_OPTS+=("--add-module=/tmp/lua-resty-events")
        OPENRESTY_OPTS+=('--with-stream_realip_module')
        OPENRESTY_OPTS+=('--with-stream_ssl_preread_module')
        OPENRESTY_OPTS+=('--with-pcre=/tmp/pcre')
        OPENRESTY_OPTS+=("--with-ld-opt='-L/tmp/build/usr/local/kong/lib -Wl,--disable-new-dtags,-rpath,/usr/local/kong/lib'")
        OPENRESTY_OPTS+=("--with-cc-opt='-I/tmp/build/usr/local/kong/include'")

        eval ./configure ${OPENRESTY_OPTS[*]} || tee /tmp/00-openresty-configure.log

        make -j2 || tee /tmp/01-openresty-build.log
        make -j2 install DESTDIR=/tmp/build || tee /tmp/02-openresty-install.log
    popd

    pushd /tmp/lua-kong-nginx-module
        make install LUA_LIB_DIR=/tmp/build/usr/local/openresty/lualib
    popd

    pushd /tmp/lua-resty-lmdb
        make install LUA_LIB_DIR=/tmp/build/usr/local/openresty/lualib
    popd

    pushd /tmp/lua-resty-events
        make install LUA_LIB_DIR=/tmp/build/usr/local/openresty/lualib
    popd
    echo '--- installed openresty ---'

    pushd /tmp/luarocks-${LUAROCKS_VERSION}
        echo '--- installing luarocks ---'
        ./configure \
            --prefix=/usr/local \
            --with-lua=/tmp/build/usr/local/openresty/luajit \
            --with-lua-include=/tmp/build/usr/local/openresty/luajit/include/luajit-2.1

        make build -j2
        make install DESTDIR=/tmp/build
        echo '--- installed luarocks ---'
    popd

    arch=$(uname -m)

    package_architecture=x86_64
    if [ "$(arch)" == "aarch64" ]; then
        package_architecture=aarch64
    fi

    curl -fsSLo atc-router.tar.gz https://github.com/hutchic-org/atc-router-compiled/releases/download/$ATC_ROUTER_VERSION/$package_architecture-unknown-$OSTYPE.tar.gz
    tar -C /tmp/build -xvf atc-router.tar.gz

    mkdir -p /tmp/build/usr/local/lib/luarocks
    mkdir -p /tmp/build/usr/local/share/lua
    mkdir -p /tmp/build/usr/local/lib/lua

    sed -i 's/\/tmp\/build//' `grep -l -I -r '\/tmp\/build' /tmp/build/`
    echo '--- installed kong runtime ---'
}

# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
# Successive backoffs double the timeout.
function with_backoff {
    local max_attempts=${ATTEMPTS-5}
    local timeout=${TIMEOUT-5}
    local attempt=1
    local exitCode=0

    while (( $attempt < $max_attempts ))
    do
        if "$@"
        then
            return 0
        else
            exitCode=$?
        fi

        echo "Failure! Retrying in $timeout.." 1>&2
        sleep $timeout
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
    done

    if [[ $exitCode != 0 ]]
    then
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

main
