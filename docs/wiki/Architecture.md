# Architecture

Use this page for technical direction while the codebase is still forming.

## Platform

Target iOS and Android.

The client platform is not locked yet. Current recommendation:

- Prefer native iOS + native Android with Matrix Rust SDK bindings if long-term Matrix correctness, end-to-end encryption, and platform behavior are the top priorities.
- Consider Flutter with `matrix-dart-sdk` for a faster voice-note prototype if we accept a validation phase around encryption, sync reliability, push, and native audio behavior.

Decision checkpoint: build a small client spike before committing to the production client stack.

Current scaffold:

- Monorepo root with Gradle wrapper.
- `apps/android/` Kotlin Android app using Jetpack Compose.
- Android app depends on `org.matrix.rustcomponents:sdk-android`.
- `services/synapse/` contains a Docker Compose based local Synapse setup that only runs when started by script.

## System Overview

FamLink should use Matrix as the durable messaging and history layer, not as a live streaming transport.

Core architecture:

- Synapse homeserver for users, rooms, events, sync, media, and push integration.
- One private Matrix direct room per approved family-member tile.
- Voice notes represented as Matrix `m.audio` events.
- Optional Matrix account data for user-specific FamLink settings such as per-tile live mode.
- Mobile client owns recording, upload, playback queueing, auto-play rules, and the tile-first interface.

Out of scope for v1:

- MatrixRTC.
- LiveKit.
- WebRTC.
- TURN.
- LTE/carrier integration.
- Default dialer replacement.

These may become relevant only if the product later needs true live calls or group voice rooms.

## Data Model

### Matrix Objects

- User: one Matrix user per family member.
- Room: one encrypted 1:1 Matrix room per approved relationship.
- Event: one `m.audio` event per voice note.
- Media: uploaded audio file referenced by the `m.audio` event.
- Account data: optional client settings, such as which rooms have live mode enabled.

### FamLink Client Concepts

- Tile: local UI representation of a Matrix room and its other participant.
- Live mode: a local or synced playback preference that auto-plays newly received voice notes when allowed.
- Playback queue: ordered local queue for incoming voice notes that should play automatically.
- Message state: derived from Matrix sync, delivery, read, and playback state.

Example voice-note event shape:

```json
{
  "msgtype": "m.audio",
  "body": "Voice message",
  "url": "mxc://famlink.example/media-id",
  "info": {
    "mimetype": "audio/ogg",
    "duration": 8300,
    "size": 74211
  },
  "com.famlink.voice": {
    "kind": "ptt",
    "client_generated_at": "2026-04-17T12:00:00Z"
  }
}
```

## Authentication And Permissions

- Closed or invite-only account creation for early versions.
- Family relationship approval maps naturally to Matrix room invites and joins.
- QR-code invite flow is likely easier for families than manually typing Matrix IDs.
- Phone-number discovery should be treated as a later product decision, not a v1 dependency.
- The app needs microphone permission for recording and notification permission for delivery alerts.

## Offline And Sync

- Matrix sync provides room timelines and missed events.
- Voice notes should upload after recording; if offline, queue locally and send when connectivity returns.
- Incoming voice notes should remain playable from history after download/decryption.
- Live mode is best-effort auto-play. If the client cannot auto-play immediately, the note remains in history and should surface as unread.

## Security And Privacy

- Voice notes are sensitive family audio and should be treated as private by default.
- End-to-end encryption should be strongly preferred, but it increases client complexity.
- Push notifications should avoid exposing transcript-like content or sensitive audio details.
- Media encryption should be validated during the client SDK spike.
- Device verification and account recovery need simple user experience if E2EE is enabled.

## Open Technical Questions

- Is `matrix-dart-sdk` sufficient for encrypted media, sync, push, and production mobile reliability?
- How much platform-specific work would Flutter still require for audio sessions, background behavior, and notifications?
- Can Matrix Rust SDK bindings be used comfortably from the chosen mobile stack?
- Should v1 ship with E2EE enabled, or should a prototype validate flows before enabling it?
- What exactly should live mode do when the app is backgrounded, locked, or killed?
