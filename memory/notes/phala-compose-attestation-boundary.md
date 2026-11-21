---
title: Phala compose separates attested configuration from runtime secrets
type: module
scope: "docker-compose.phala.yml"
confidence: 0.98
sources: [19]
updated: 2026-11-21
---
The Phala compose text is an attestation boundary: literal configuration is covered, while host-supplied environment values are not.
`docker-compose.phala.yml` deliberately fixes Google issuer, scopes, API base URL, provider mode, and type as literals; credentials are interpolated separately.
An environment value must also appear in the service's `environment` mapping to reach that container; sealing or supplying a value alone does not expose it to the app.
Review deployment refactors for preservation of this boundary: do not move provider endpoints into runtime configuration merely to simplify secret loading.
Image selection must resolve to an exact digest in the compose text presented to dstack, rather than an operator-controlled mutable tag.
