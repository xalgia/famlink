# Project Brief

## One-Sentence Pitch

FamLink is a private family voice-note intercom: hold a family tile to record a short voice message that either auto-plays for listeners in live mode or stays in history.

## Problem

Family communication often flips between two awkward extremes: calls require everyone to be available at once, while text chat makes quick human context feel slow or easy to miss. FamLink should make short spoken updates feel as easy as using a walkie-talkie while still preserving every message as history.

## Primary Users

- Family members who coordinate day-to-day logistics.
- Caregivers who need quick spoken updates without starting full calls.
- Less technical relatives who should be able to receive and reply from a simple tile-based interface.

## Jobs To Be Done

- Add a trusted family member and wait for them to approve the connection.
- Press and hold a family tile to send a short voice note.
- Hear selected family members automatically when live mode is enabled.
- Review earlier voice notes from a relationship history.
- Avoid exposing private family audio to the wrong people or services.

## Initial Scope

- 1:1 family member tiles.
- Voice-note messages only; no true live streaming in v1.
- Per-tile live mode, where newly received voice notes can auto-play when the app is active/listening.
- Matrix-backed identity, invitations, rooms, sync, media, and history.
- Push notification fallback when auto-play is not available.

## Non-Goals

- Carrier/LTE calling integration.
- Replacing the phone dialer.
- Real-time WebRTC, MatrixRTC, or group voice rooms in the first product slice.
- Public social discovery.
- General-purpose text chat UI.

## Success Signals

- A user can add a family member and see them as a tile after approval.
- A user can send a short voice note in one press-and-hold gesture.
- A recipient can receive, auto-play when eligible, and replay the same message from history.
- Missed live-mode messages still appear as durable voice notes.
- The interface remains understandable to a non-technical family member.

## Constraints

- Mobile OS background behavior limits guaranteed auto-play. Foreground or explicitly active listening mode is the reliable baseline.
- Voice notes are private family data and should be treated as sensitive.
- Matrix can provide the protocol foundation, but the FamLink client owns the walkie-talkie-style product behavior.

## Open Questions

- Should v1 require end-to-end encryption from the beginning?
- Should live mode be global, per-tile, or both?
- What is the maximum voice-note length for v1?
- Should the first client be Flutter for speed, or native iOS/Android with Matrix Rust SDK for long-term Matrix/E2EE strength?
