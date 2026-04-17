# 0002: Use Matrix Voice Notes Instead Of Live Audio Streaming

## Status

Accepted for the first product slice.

## Context

FamLink should feel like a walkie-talkie, but it does not need true live audio transport. Every message can be recorded, stored, delivered, and replayed as a voice note. "Live mode" means newly received voice notes auto-play when the receiving client is active/listening and playback is allowed.

## Decision

Use Matrix as the voice-note messaging and history layer:

- send voice notes as Matrix `m.audio` events;
- store history in private Matrix rooms;
- map each approved family member tile to a 1:1 Matrix room;
- implement live mode as client-side auto-play behavior;
- defer WebRTC, MatrixRTC, LiveKit, TURN, and LTE/call-stack integration.

## Consequences

- The first version can avoid real-time media infrastructure.
- Missed live-mode messages still work as durable voice notes.
- Mobile background limitations become a product constraint rather than a transport failure.
- The client must own recording, upload, playback, queueing, and live-mode rules.

## References

- Matrix `m.audio`: https://spec.matrix.org/latest/client-server-api/#maudio
- Matrix Client-Server API: https://spec.matrix.org/latest/client-server-api/
