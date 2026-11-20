# Deployment to Phala

This document describes how to deploy OAuth3 to Phala's TEE infrastructure.

## Phala Cloud

Phala deploys go only through the organization's shared Phala flow
(`burnt-labs/github-workflows` `.github/workflows/phala-deploy.yml`). This
repository holds its policy, `.github/phala-policy.jsonc` (plus
`.github/quality-policy.jsonc` for the quality gates the flow runs first), and
one thin caller, `.github/workflows/phala-deploy.yml`. There is no
repository-local deploy script or CLI path; a new need is added to the shared
flow, never here.

### The image

`.github/workflows/docker-build.yml` builds the image with Nix on pull requests
and, on merge to `main`, promotes it to `ghcr.io/burnt-labs/oauth3:main`,
`:latest` and `:main-<merge commit sha>`. The digest to deploy is printed in
that run's "Promote image to latest" step (`Digest: sha256:...`), or read it
from the registry:

```bash
crane digest ghcr.io/burnt-labs/oauth3:main-<merge commit sha>
```

`docker-compose.phala.yml` references the app image as `${APP_IMAGE}`. The
shared flow replaces it with `ghcr.io/burnt-labs/oauth3@<digest>` before the
deploy, after proving the sealed registry login can pull that digest, so the
attested compose hash names the exact image running.

### Operations

Run **Phala Deploy** (`.github/workflows/phala-deploy.yml`) from `main` with
`target: release` (CVM `oauth3-redacted`, `https://oauth3.burnt.com`):

| Operation | What it does                                                                                       | `image-digest` |
| --------- | -------------------------------------------------------------------------------------------------- | -------------- |
| `setup`   | Creates the CVM when none has that name, once, with the infrastructure in the policy's `setup` block | required       |
| `update`  | Deploys a new image to the existing CVM in place (same app id)                                     | required       |
| `reseal`  | Re-applies the sealed environment and restarts; no image or compose change                         | empty          |

Every operation health-checks `https://oauth3.burnt.com/healthz`. `update` and
`setup` change the compose hash, so anything that pins the attested
measurements must be re-pinned after them.

There is no candidate CVM. The compose file is production's (dstack-ingress
claims `oauth3.burnt.com` and manages its DNS), so a candidate needs its own
domain in the compose before the caller can offer it.

### Configuration

Runtime secrets come only from the target's 1Password item in vault `Deploy`:
`op://Deploy/oauth3 production` for `release` (`op://Deploy/oauth3 staging`
is declared for the unused candidate). The flow reads it with the service
account token in the organization secret `OP_DEPLOY_SERVICE_ACCOUNT_TOKEN` and
seals each value into the CVM under its field's name. The item has exactly one
**concealed** custom field per name the compose consumes, labelled with that
name: `APP_PUBLIC_URL`, `COOKIE_KEY_BASE64`, `PROVIDER_GOOGLE_CLIENT_ID`,
`PROVIDER_GOOGLE_CLIENT_SECRET`, `CLOUDFLARE_API_TOKEN`, `CERTBOT_EMAIL`. A
missing, extra, empty or unconcealed field fails the run before it deploys.
They are not GitHub secrets.

Deployment credentials stay GitHub secrets:

- `PHALA_API_KEY`: API key of the Phala workspace that owns the CVM
- `GHCR_READ_TOKEN`: organization read-package token, sealed as the CVM's
  registry login

Non-secret configuration is hardcoded in `docker-compose.phala.yml` so it is
covered by attestation.

## Self-Hosted dstack

For running on your own TDX infrastructure:

### Prerequisites

- TDX-enabled server (Intel 4th/5th gen Xeon)
- Ubuntu 22.04 or later
- 16GB+ RAM, 100GB+ disk
- Public IPv4 address

### Installation

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
- [ ] Fill the fields listed under Configuration in `op://Deploy/oauth3 production`
- [ ] Configure provider OAuth credentials (Google, GitHub, etc.)
- [ ] Configure domain and SSL/TLS
- [ ] Test attestation endpoint works in TEE

## File Structure

**Deployment files:**

```
oauth3/
├── docker-compose.phala.yml              # Production compose (app + dstack-ingress)
├── .github/phala-policy.jsonc            # Shared Phala flow policy
├── .github/quality-policy.jsonc          # Quality gates the flow runs first
├── .github/workflows/phala-deploy.yml    # Thin caller of the shared flow
└── scripts/pre-launch.sh                 # CVM pre-launch (docker login + pull)
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

Use the Phala Cloud dashboard for the CVM's status and logs.

## Data Persistence

CVM volumes are LUKS-encrypted and persist across restarts and redeployments. However:

- **Physical disk failure** will lose data (no built-in backup)
- **Docker image hash changes** change the KMS-derived encryption keys, making old data inaccessible

`update` deploys to the existing CVM in place, keeping its app id; it no longer
creates a fresh CVM per deploy. Check the key-derivation note above against the
dstack version in use before relying on data surviving an image change.

## Support

- Phala Cloud: https://cloud.phala.com
- dstack GitHub: https://github.com/Dstack-TEE/dstack
- Documentation: https://docs.phala.com/dstack
