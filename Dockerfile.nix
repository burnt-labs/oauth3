# Local development convenience: builds a reproducible Linux image on macOS via Docker.
# NOT used in CI or production. CI uses `nix build .#dockerImage` directly (see .github/workflows/docker-build.yml).
# Phala deployment pulls the pre-built image from GHCR.
FROM nixos/nix:2.26.3 AS builder

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /build

# Copy source
COPY . .

# Build the application using Nix
RUN nix build .#oauth3 --no-link --print-out-paths > /tmp/out-path

# Get all runtime dependencies (closure)
RUN nix-store -qR $(cat /tmp/out-path) > /tmp/closure-paths

# Create a minimal root with only runtime dependencies
RUN mkdir -p /tmp/minimal-root/nix/store && \
    cat /tmp/closure-paths | xargs -I {} cp -r {} /tmp/minimal-root/nix/store/

# Resolve paths at build time and create symlinks + SSL certs + passwd
RUN OUT=$(cat /tmp/out-path) && \
    mkdir -p /tmp/minimal-root/usr/local/bin && \
    ln -s "$OUT/bin/oauth3" /tmp/minimal-root/usr/local/bin/oauth3 && \
    mkdir -p /tmp/minimal-root/app/data && \
    cp -r "$OUT/share/oauth3/migrations" /tmp/minimal-root/app/migrations && \
    cp "$OUT/share/oauth3/diesel.toml" /tmp/minimal-root/app/diesel.toml && \
    # SSL certs
    CERT=$(find /tmp/minimal-root/nix -name 'ca-bundle.crt' -path '*/etc/ssl/certs/*' | head -1) && \
    mkdir -p /tmp/minimal-root/etc/ssl/certs && \
    ln -sf "${CERT#/tmp/minimal-root}" /tmp/minimal-root/etc/ssl/certs/ca-certificates.crt && \
    # passwd for nobody user
    echo "nobody:x:65534:65534:Nobody:/nonexistent:/bin/false" > /tmp/minimal-root/etc/passwd && \
    # tmp dir
    mkdir -p /tmp/minimal-root/tmp

# Minimal runtime - scratch (no shell, no extra attack surface)
FROM scratch

COPY --from=builder /tmp/minimal-root /

WORKDIR /app
USER nobody
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/oauth3"]
