# Worklog

Use this page as the active trail of what changed, why it changed, and what remains open.

## Format

Each entry should include:

- Date and time when helpful.
- Goal or task.
- Changes made.
- Commands run or checks performed.
- Blockers, risks, or follow-ups.

## 2026-04-16

### Goal

Set up the project workspace and create a local Markdown wiki for planning.

### Changes

- Initialized a Git repository on `main`.
- Added a lightweight `.gitignore`.
- Added a project `README.md`.
- Created `docs/wiki/` with planning, research, architecture, meeting notes, glossary, decision, and worklog pages.
- Added the first decision record: `0001-use-a-local-markdown-wiki`.

### Checks

- Confirmed the folder started empty.
- Confirmed the repository is on branch `main`.
- Confirmed all initial files are staged.

### Blockers

- Initial commit is blocked until local Git author identity is configured.

### Next

- Configure Git author identity.
- Commit the initial wiki setup.
- Fill in the project brief.

## 2026-04-17

### Goal

Capture the current product and architecture direction for FamLink before implementation.

### Changes

- Defined FamLink as a private family voice-note intercom.
- Clarified that v1 uses stored voice notes only; live mode is client-side auto-play, not true streaming.
- Documented a Matrix/Synapse architecture using private 1:1 rooms and `m.audio` events.
- Added product flows for adding family members, sending voice notes, normal receive, and live-mode receive.
- Added decision records for the Matrix voice-note direction and client framework validation.
- Added research references for Matrix, Synapse, Matrix Rust SDK, Matrix Dart SDK, and mobile notification constraints.
- Updated the glossary and wiki current focus.

### Checks

- Reviewed the documentation diff.
- Searched the wiki for remaining `TBD` entries and relevant Matrix/client-framework terms.

### Open Questions

- Should v1 require end-to-end encryption from the beginning?
- Should live mode be global, per-tile, or both?
- What is the maximum voice-note length for v1?
- Should the first implementation spike use Flutter plus Matrix Dart SDK, native iOS/Android plus Matrix Rust SDK bindings, or both?

## 2026-04-17 Monorepo Scaffold

### Goal

Create the first executable monorepo scaffold and local Matrix development setup.

### Changes

- Added root Gradle monorepo files and Gradle wrapper.
- Added `apps/android/` as a blank Kotlin Android app with Jetpack Compose.
- Added the Matrix Rust Android SDK artifact dependency.
- Added `services/synapse/` with Docker Compose config for debug-only local Synapse.
- Added `scripts/dev/` helpers to start, stop, log, and register users for local Synapse.
- Documented the layout and commands in the README files.
- Added decision record `0004-use-monorepo-local-synapse-android-rust`.

### Checks

- Built the Android app with `ANDROID_HOME=/home/x/Android/Sdk ./gradlew :apps:android:assembleDebug`.
- Syntax-checked local Matrix helper scripts with `bash -n`.
- Confirmed `./scripts/dev/matrix-start.sh` exits clearly when Docker is unavailable.

### Notes

- Docker is not currently installed on this machine, so the Synapse scripts can be syntax-checked but the local homeserver cannot be started here until Docker or compatible tooling is available.
