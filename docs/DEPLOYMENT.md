# Deployment to Phala

This document describes how to deploy OAuth3 to Phala's TEE infrastructure.

## Quick Start: Phala Cloud Deployment

### Prerequisites

- Phala Cloud account
- Docker image published to GHCR (CI does this automatically on push to main)

### Steps

1. **Configure environment**

```bash
# Copy Phala environment template
cp .env.phala.example .env.phala

# Edit with your values
nano .env.phala
```

**Required variables in `.env.phala`:**

```bash
DOCKER_IMAGE=ghcr.io/burnt-labs/oauth3:latest
POSTGRES_PASSWORD=your-secure-password
COOKIE_KEY_BASE64=$(openssl rand -base64 64)

# APP_PUBLIC_URL - can be set after deployment when you know the URL
APP_PUBLIC_URL=https://your-cvm-url.phala.network

# OAuth providers
PROVIDER_GOOGLE_TYPE=oidc
PROVIDER_GOOGLE_MODE=live
PROVIDER_GOOGLE_CLIENT_ID=your-client-id
PROVIDER_GOOGLE_CLIENT_SECRET=your-client-secret
PROVIDER_GOOGLE_ISSUER=https://accounts.google.com
PROVIDER_GOOGLE_SCOPES=openid profile email
PROVIDER_GOOGLE_API_BASE_URL=https://www.googleapis.com
```

**Note on APP_PUBLIC_URL:**

- You won't know your public URL until after deployment
- The script will deploy with a placeholder if not set
- After deployment, get your URL from `phala apps`
- Configure OAuth callback URLs with providers using the Phala URL

2. **Deploy to Phala Cloud**

```bash
# Install Phala Cloud CLI
npm install -g @phala/cloud-cli

# Login
phala login

# Fresh deploy
./scripts/phala-deploy.sh .env.phala

# Deploy with data migration from existing CVM
./scripts/phala-deploy.sh .env.phala old-cvm-name
```

The script always creates a new CVM. When an old CVM name is provided, it migrates the Postgres data via `phala ssh` + `pg_dump`.

3. **Verify deployment**

```bash
# Check CVM status
phala apps

# View logs
phala logs <cvm-name>
```

### Option 2: Self-Hosted dstack

For running on your own TDX infrastructure:

#### Prerequisites

- TDX-enabled server (Intel 4th/5th gen Xeon)
- Ubuntu 22.04 or later
- 16GB+ RAM, 100GB+ disk
- Public IPv4 address

#### Installation

1. **Install dependencies**

```bash
sudo apt install -y build-essential chrpath diffstat lz4 wireguard-tools xorriso
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. **Clone and build dstack**

```bash
git clone https://github.com/Dstack-TEE/meta-dstack.git --recursive
cd meta-dstack/
mkdir build
cd build
../build.sh hostcfg
```

3. **Configure build-config.sh** with your settings

4. **Download guest image**

```bash
../build.sh dl 0.5.2
```

5. **Start dstack components**

In separate terminals:

```bash
# Terminal 1: KMS
./dstack-kms -c kms.toml

# Terminal 2: Gateway (requires sudo)
sudo ./dstack-gateway -c gateway.toml

# Terminal 3: VMM
./dstack-vmm -c vmm.toml
```

6. **Deploy via web interface**

Open `http://localhost:9080` and upload your `docker-compose.phala.yml`

## Production Checklist

Before deploying:

- [ ] Docker image built and pushed to GHCR (CI handles this)
- [ ] Set production environment variables in `.env.phala`
- [ ] Configure provider OAuth credentials (Google, GitHub, etc.)
- [ ] Configure domain and SSL/TLS
- [ ] Test attestation endpoint works in TEE

## File Structure

**Deployment files:**

```
oauth3/
├── docker-compose.phala.yml    # Production compose (app + db)
├── scripts/phala-deploy.sh     # Deployment script
├── scripts/pre-launch.sh       # CVM pre-launch (docker login + pull)
└── .env.phala                  # Production environment (not committed)
```

**Development only (not deployed):**

- `docker-compose.yml` (local dev with simulator + dex)
- `Dockerfile` (non-reproducible dev build)
- `Dockerfile.nix` (local macOS reproducible build)
- `dex-config.yaml`
- `tests/`

## Attestation

Once deployed in TEE, test attestation:

```bash
curl 'https://your-domain.com/proxy/google/oauth2/v2/userinfo?attest=true' \
  -H 'Authorization: Bearer oak_YOUR_API_KEY'
```

The response will include TEE attestation quote and event log proving execution in a trusted environment.

## Monitoring

```bash
phala logs <cvm-name> --follow
```

## Data Persistence

CVM volumes are LUKS-encrypted and persist across restarts and redeployments. However:

- **Physical disk failure** will lose data (no built-in backup)
- **Docker image hash changes** change the KMS-derived encryption keys, making old data inaccessible

The deploy script always creates a fresh CVM to avoid key mismatch issues. Use the migration flag to transfer data:

```bash
./scripts/phala-deploy.sh .env.phala old-cvm-name
```

## Support

- Phala Cloud: https://cloud.phala.com
- dstack GitHub: https://github.com/Dstack-TEE/dstack
- Documentation: https://docs.phala.com/dstack
