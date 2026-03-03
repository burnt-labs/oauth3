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

# Resolve paths at build time and create symlinks
RUN OUT=$(cat /tmp/out-path) && \
    mkdir -p /tmp/minimal-root/usr/local/bin && \
    ln -s "$OUT/bin/oauth3" /tmp/minimal-root/usr/local/bin/oauth3 && \
    mkdir -p /tmp/minimal-root/app && \
    cp -r "$OUT/share/oauth3/migrations" /tmp/minimal-root/app/migrations && \
    cp "$OUT/share/oauth3/diesel.toml" /tmp/minimal-root/app/diesel.toml

# Minimal runtime - busybox base with Nix closure
FROM busybox:1.37

# Copy the Nix store closure, symlinks, and app files
COPY --from=builder /tmp/minimal-root /

# Set up SSL certs from Nix closure
RUN CERT=$(find /nix -name 'ca-bundle.crt' -path '*/etc/ssl/certs/*' | head -1) && \
    mkdir -p /etc/ssl/certs && \
    ln -sf "$CERT" /etc/ssl/certs/ca-certificates.crt

# Create passwd entry for nobody
RUN echo "nobody:x:65534:65534:Nobody:/nonexistent:/bin/false" >> /etc/passwd

WORKDIR /app
USER nobody
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/oauth3"]
