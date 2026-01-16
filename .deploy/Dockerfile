# ============================================================================
# ZEA Thalamus - Production Docker Build
# ============================================================================
# Multi-stage build for optimal image size and security
# ============================================================================

# ============================================================================
# STAGE 1: Dependencies
# ============================================================================
FROM elixir:1.17-alpine AS deps

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git

# Create app directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# ============================================================================
# STAGE 2: Build
# ============================================================================
FROM deps AS build

# Set build environment
ENV MIX_ENV=prod

# Copy application source
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Copy assets
COPY assets ./assets

# Compile dependencies
RUN mix deps.compile

# Compile application
RUN mix compile

# Build assets (uses esbuild and tailwind)
RUN mix assets.deploy

# Build release
RUN mix release

# ============================================================================
# STAGE 3: Runtime
# ============================================================================
FROM elixir:1.17-alpine AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    ca-certificates \
    wget

# Create non-root user for security
RUN addgroup -g 1000 thalamus && \
    adduser -D -u 1000 -G thalamus thalamus

# Create app directory
WORKDIR /app

# Copy release from build stage
COPY --from=build --chown=thalamus:thalamus /app/_build/prod/rel/thalamus ./

# Switch to non-root user
USER thalamus

# Expose port
EXPOSE 4000

# Set environment variables
ENV HOME=/app
ENV PORT=4000
ENV MIX_ENV=prod
ENV SHELL=/bin/bash

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start application
CMD ["bin/thalamus", "start"]
