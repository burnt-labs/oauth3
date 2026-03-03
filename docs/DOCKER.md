# Docker Compose Configuration

This project uses two Docker Compose files for different environments.

## File Structure

- **`docker-compose.yml`** - Local development (app + database + simulator + dex)
- **`docker-compose.phala.yml`** - Production deployment on Phala Cloud (app + database only)

## Local Development

```bash
docker compose up
```

This includes:
- PostgreSQL database
- OAuth3 app (built from `Dockerfile`)
- Phala dstack simulator (for TEE attestation testing)
- Dex OIDC provider (for OAuth testing)

## Production / Phala Deployment

Production uses `docker-compose.phala.yml` which is deployed to a Phala CVM via the deploy script:

```bash
./scripts/phala-deploy.sh .env.phala
```

This includes:
- PostgreSQL database (encrypted volume inside TEE)
- OAuth3 app (pre-built image from GHCR)
- Real TEE environment (provided by Phala infrastructure)

See [DEPLOYMENT.md](DEPLOYMENT.md) for full instructions.

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your configuration
```

Required for production:
- `DATABASE_URL` - Postgres connection string
- `APP_PUBLIC_URL` - Public URL of the app
- `COOKIE_KEY_BASE64` - Base64-encoded 64-byte key
- Provider credentials (GOOGLE_CLIENT_ID, GITHUB_CLIENT_ID, etc.)

## Testing

Run integration tests against the Docker environment:

```bash
# Start dev environment
docker compose up -d

# Run tests
cargo test --test proxy_endpoint -- --ignored
cargo test --test oidc_dex_docker -- --ignored
```
