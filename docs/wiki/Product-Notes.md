# Product Notes

Use this page for rough feature ideas, user flows, sketches in words, and product tradeoffs.

## User Flows

### Flow: Add A Family Member

1. The user enters a Matrix ID, phone-derived invite, or scans a QR code.
2. FamLink creates or identifies a private 1:1 Matrix room.
3. The invited family member receives an approval prompt.
4. After approval, both clients show the relationship as a tile.
5. The room timeline becomes that tile's voice history.

### Flow: Send A Voice Note

1. The user presses and holds a family tile.
2. FamLink records microphone audio locally.
3. On release, FamLink encodes and uploads the audio as Matrix media.
4. FamLink sends an `m.audio` event into the relationship room.
5. The tile shows sent/delivered state from Matrix sync.

### Flow: Receive In Normal Mode

1. FamLink receives an `m.audio` event through Matrix sync or push.
2. The tile shows an unread/new-message state.
3. The recipient taps the tile or message to play the voice note.
4. The message remains available in history.

### Flow: Receive In Live Mode

1. FamLink receives an `m.audio` event from a tile with live mode enabled.
2. If the app is active/listening and playback is allowed, it downloads/decrypts the audio.
3. The audio is added to a playback queue.
4. FamLink plays queued notes in order without overlapping.
5. If auto-play is unavailable, the message falls back to normal voice-note notification/history behavior.

## Feature Ideas

- Tile-first home screen, with one tile per approved family member.
- Per-tile live mode toggle.
- Short max-duration voice notes, likely 30 seconds or less for v1.
- Playback queue for live mode.
- Speaker/headphone behavior that is explicit and understandable.
- Voice-note history under each tile.
- Optional family groups later, once 1:1 behavior is proven.

## Risks

- Users may expect true walkie-talkie behavior even though the product is voice-note delivery plus auto-play.
- iOS and Android may restrict background auto-play; the product promise should avoid guaranteeing playback when the app is killed or locked.
- Auto-playing family audio can be socially risky in public; live mode needs clear controls.
- Matrix end-to-end encryption improves privacy but adds onboarding, device verification, recovery, and SDK complexity.
- Flutter can speed up UI development, but native audio/push/platform behavior may still need substantial platform-specific work.
