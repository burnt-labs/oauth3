# Resolve OAuth2 dependency vulnerabilities

## Goal

Remove every open Dependabot finding from both Rust lockfiles without weakening TDX attestation verification or changing OAuth behavior.

## Approach

1. Upgrade `dcap-qvl` to the maintained 0.6 line and adapt collateral fetching to its typed `CollateralClient` API while preserving the existing production-root verification and report extraction.
2. Refresh Diesel, Serde With, Quinn, WebPKI, and both Rand lines to their patched releases in the root lockfile.
3. Regenerate the standalone `dstack-verifier/Cargo.lock` from the same maintained manifest so it contains the identical patched attestation graph.
4. Run formatting, strict Clippy, the complete root and verifier test suites, release builds, and RustSec audits for both locks.
5. Publish one superseding PR only after both lockfiles audit clean and the branch is merged with current `main`.

## Risk boundary

Attestation verification must continue to fetch Intel collateral through the configured PCCS URL and verify with the library production-root policy. Do not enable debug, service-TD, TCB override, or permissive fallback modes. Any report-field or event-log behavior change blocks publication.
