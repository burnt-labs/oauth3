# Multi-stage Dockerfile for building and running the oauth3 server (Axum + Diesel/SQLite)
# Single-container build: no external database needed.

FROM rust:1.92-bullseye AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy toolchain file early so the correct rust/cargo are used during caching
COPY rust-toolchain.toml ./

# Show toolchain versions for diagnostics
RUN rustc --version && cargo --version

# Create a dummy build to cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release || true

# Copy actual source and build
COPY . .
RUN cargo build --release

FROM debian:bullseye-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/oauth3 /usr/local/bin/oauth3
COPY migrations ./migrations
COPY static ./static

# Non-root user
RUN useradd -m -u 10001 appuser && \
    mkdir -p /app/data && \
    chown -R appuser:appuser /app
USER appuser

# Default environment (can be overridden by Compose)
ENV APP_BIND_ADDR=0.0.0.0:8080 \
    APP_PUBLIC_URL=http://localhost:8080 \
    DATABASE_URL=sqlite:///app/data/oauth3.db

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/oauth3"]
