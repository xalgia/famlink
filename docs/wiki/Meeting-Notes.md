# Meeting Notes

## 2026-04-16

### Topics

- Created the initial Git repository.
- Created a local Markdown wiki scaffold.

### Notes

- Initial wiki scaffold was created before product direction was defined.

### Follow-Ups

- Fill out the project brief.
- Decide the first product slice.

## 2026-04-17

### Topics

- Explored FamLink as a Matrix-backed family voice app.
- Clarified that messages do not need true live streaming.
- Reframed live behavior as automatic playback of stored voice notes.
- Compared Flutter/Matrix Dart SDK with native clients/Matrix Rust SDK bindings.

### Notes

- V1 should use voice notes only, represented as Matrix `m.audio` events.
- Live mode is a client playback rule, not a transport protocol.
- One approved family member tile can map to one private Matrix room.
- Matrix/Synapse can provide identity, invites, rooms, sync, media, push integration, and history.
- Mobile OS background limits mean auto-play should be promised only for active/listening states, with notification/history fallback.
- Native clients with Matrix Rust SDK bindings look strongest for long-term Matrix/E2EE reliability.
- Flutter with Matrix Dart SDK remains plausible for a prototype, but must be validated.

### Follow-Ups

- Decide whether E2EE is required for v1.
- Decide whether live mode is global, per-tile, or both.
- Decide the v1 maximum voice-note length.
- Run a client SDK spike before committing to Flutter or native.
