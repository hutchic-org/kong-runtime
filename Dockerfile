ARG OSTYPE=linux-gnu
ARG ARCHITECTURE=x86_64
ARG DOCKER_REGISTRY=ghcr.io
ARG DOCKER_IMAGE_NAME

# ATC-router image to copy in the installed atc-router
# List out all image permutations to trick dependabot
FROM --platform=linux/arm64 ghcr.io/hutchic-org/atc-router-compiled:1.1.3-x86_64-unknown-linux-musl as atc-router-x86_64-linux-musl
FROM --platform=linux/arm64 ghcr.io/hutchic-org/atc-router-compiled:1.1.3-x86_64-unknown-linux-gnu as atc-router-x86_64-linux-gnu
FROM --platform=linux/arm64 ghcr.io/hutchic-org/atc-router-compiled:1.1.3-aarch64-unknown-linux-musl as atc-router-aarch64-linux-musl
FROM --platform=linux/arm64 ghcr.io/hutchic-org/atc-router-compiled:1.1.3-aarch64-unknown-linux-gnu as atc-router-aarch64-linux-gnu

# Kong openssl image as our base
# List out all image permutations to trick dependabot
FROM --platform=linux/amd64 ghcr.io/hutchic-org/kong-openssl:1.0.3-x86_64-linux-musl as x86_64-linux-musl
FROM --platform=linux/amd64 ghcr.io/hutchic-org/kong-openssl:1.0.3-x86_64-linux-gnu as x86_64-linux-gnu
FROM --platform=linux/arm64 ghcr.io/hutchic-org/kong-openssl:1.0.3-aarch64-linux-musl as aarch64-linux-musl
FROM --platform=linux/arm64 ghcr.io/hutchic-org/kong-openssl:1.0.3-aarch64-linux-gnu as aarch64-linux-gnu

FROM atc-router-$ARCHITECTURE-$OSTYPE as atc-router

# Run the build script
FROM $ARCHITECTURE-$OSTYPE as build

COPY . /tmp
WORKDIR /tmp

# Run our predecessor tests
# Configure, build, and install
# Run our own tests
# Re-run our predecessor tests
ENV DEBUG=0
COPY --from=atc-router / /
RUN /test/*/test.sh && \
    /tmp/build.sh && \
    /tmp/test.sh && \
    /test/*/test.sh

# Test scripts left where downstream images can run them
COPY test.sh /test/kong-runtime/test.sh
COPY .env /test/kong-runtime/.env

# Copy the build result to scratch so we can export the result
FROM scratch as package

COPY --from=build /tmp/build /