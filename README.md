# FamLink

FamLink is a private family voice-note intercom in early planning and scaffolding.

The working project wiki lives in [docs/wiki/Home.md](docs/wiki/Home.md).

## Monorepo Layout

- [apps/](apps/): mobile app clients.
- [apps/android/](apps/android/): Kotlin Android scaffold using Jetpack Compose and Matrix Rust SDK Android components.
- [services/](services/): local development services.
- [services/synapse/](services/synapse/): debug-only local Synapse homeserver.
- [scripts/dev/](scripts/dev/): developer helper scripts.
- [docs/wiki/](docs/wiki/): planning wiki and decision records.

## Android

Build the blank Android app:

```sh
ANDROID_HOME=/home/x/Android/Sdk ./gradlew :apps:android:assembleDebug
```

The Android app currently depends on the Apache-2.0 Matrix Rust Android artifact:

```text
org.matrix.rustcomponents:sdk-android
```

## Local Matrix

Start local Synapse only when debugging:

```sh
./scripts/dev/matrix-start.sh
```

Stop it:

```sh
./scripts/dev/matrix-stop.sh
```

Follow logs:

```sh
./scripts/dev/matrix-logs.sh
```

Create a local test user after Synapse is running:

```sh
./scripts/dev/matrix-register-user.sh alice password123
```

Synapse data is stored under `services/synapse/data/` and is ignored by Git.

## Local Wiki

- [Home](docs/wiki/Home.md)
- [Project Brief](docs/wiki/Project-Brief.md)
- [Product Notes](docs/wiki/Product-Notes.md)
- [Architecture](docs/wiki/Architecture.md)
- [Research](docs/wiki/Research.md)
- [Glossary](docs/wiki/Glossary.md)
- [Meeting Notes](docs/wiki/Meeting-Notes.md)
- [Worklog](docs/wiki/Worklog.md)
- [Decisions](docs/wiki/Decisions.md)

## Working Rhythm

Capture rough thinking in notes first, then promote stable choices into the brief, architecture notes, or decision records.
Record active progress in the worklog as we go.
