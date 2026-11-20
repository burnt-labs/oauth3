# Agent Guidance

## Shared workflows

- Phala deploys run only through the organization's shared Phala flow,
  `burnt-labs/github-workflows` `.github/workflows/phala-deploy.yml`, via the
  thin caller `.github/workflows/phala-deploy.yml`. Repository-specific facts
  live in `.github/phala-policy.jsonc` (and `.github/quality-policy.jsonc` for
  the quality gates the flow runs first), never in the caller.
- Never add, restore or extend a repository-local deploy path: no deploy
  scripts, Phala CLI calls, or credential handling in this repository, even to
  unblock an outage. A new need becomes an operation of the shared flow; extend
  it there and have the caller use it.
- The caller stays thin: dispatch inputs passed straight through, the
  permissions the shared flow needs, `secrets: inherit`, and no logic.
- `.github/workflows/docker-build.yml` builds and publishes the image; it is
  not a deploy path. Deploys take its promoted digest as `image-digest`, and
  `docker-compose.phala.yml` references the app image only as `${APP_IMAGE}`.
