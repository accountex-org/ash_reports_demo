# Dockerfile for AshReportsDemo
# Based on Phoenix 1.7+ release Dockerfile

# Build stage
ARG ELIXIR_VERSION=1.18.0
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241016-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js for asset compilation
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy assets
COPY assets assets

# Install esbuild and tailwind
RUN mix assets.setup

# Compile assets
RUN mix assets.deploy

# Copy application files
COPY priv priv
COPY lib lib

# Remove large dataset to save space (only keep small and medium)
RUN rm -f priv/demo_data/large.json priv/demo_data/huge.json

# Compile the release
RUN mix compile

# Build release
COPY config/runtime.exs config/
RUN mix release

# Start a new build stage for the minimal runtime image
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/ash_reports_demo ./

USER nobody

# Fly.io specific environment variables
ENV ERL_AFLAGS="-proto_dist inet6_tcp"

CMD ["/app/bin/ash_reports_demo", "start"]
