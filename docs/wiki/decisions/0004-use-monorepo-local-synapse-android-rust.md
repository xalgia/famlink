# 0004: Use Monorepo With Local Synapse And Android Matrix Rust Scaffold

## Status

Accepted for the initial scaffold.

## Context

FamLink needs room for multiple clients, local development services, and planning docs. The first executable client should be simple but should pull in the Matrix Rust SDK path early so integration risk is visible.

The local Matrix server should be available for debugging, but it should not be installed as an always-running machine service.

## Decision

Use a monorepo layout:

- `apps/android/` for the first Kotlin Android scaffold.
- `services/synapse/` for local Synapse configuration.
- `scripts/dev/` for start/stop/log/user helper scripts.
- `docs/wiki/` for planning and decisions.

Use the Apache-2.0 Matrix Rust Android artifact in the Android scaffold:

```text
org.matrix.rustcomponents:sdk-android
```

Run local Synapse through Docker Compose only when the developer starts it with:

```sh
./scripts/dev/matrix-start.sh
```

## Consequences

- The repository can grow into multiple clients without another restructure.
- Local Matrix development is repeatable and opt-in.
- The Android build proves the Matrix Rust Android artifact resolves and packages in a blank app.
- Developers need Docker or Docker Compose-compatible tooling to run local Synapse.
