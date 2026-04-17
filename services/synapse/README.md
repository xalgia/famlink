# Local Synapse

This folder contains a debug-only Synapse homeserver for local Matrix development.

It is intentionally not installed as a machine service. Start it only when needed:

```sh
./scripts/dev/matrix-start.sh
```

Stop it with:

```sh
./scripts/dev/matrix-stop.sh
```

The local homeserver URL is:

```text
http://localhost:8008
```

Generated Synapse data lives in `services/synapse/data/` and is ignored by Git.
