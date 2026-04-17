# 0003: Validate Client Framework Before Production Commitment

## Status

Accepted as a process decision.

## Context

FamLink needs iOS and Android clients with a custom tile-first UI, microphone recording, audio playback, push notifications, Matrix sync, media upload/download, and likely end-to-end encryption.

Flutter may accelerate UI development and a shared codebase. The Matrix Dart SDK exists and is actively published, making a Flutter prototype plausible.

The Matrix Rust SDK has stronger ecosystem gravity for serious Matrix mobile clients and is used by Element X through native iOS and Android clients. It may be the better long-term foundation for Matrix correctness, encryption, and sync behavior.

## Decision

Do not lock the production client framework yet.

Run a small implementation spike before production commitment:

- voice-note send and receive;
- encrypted 1:1 room if feasible;
- media upload/download;
- push registration;
- foreground auto-play queue;
- basic background notification behavior;
- one tile mapped to one Matrix room.

Compare two candidate approaches:

- Flutter plus Matrix Dart SDK.
- Native iOS/Android plus Matrix Rust SDK bindings.

## Current Leaning

Use Flutter only if the spike proves the Matrix Dart SDK and native plugin work are sufficient for the encrypted voice-note product.

Prefer native iOS/Android with Matrix Rust SDK bindings if privacy, encryption, Matrix correctness, and platform-specific audio/push behavior are more important than fastest UI iteration.

## References

- Matrix Rust SDK: https://github.com/matrix-org/matrix-rust-sdk
- Matrix Rust Components Kotlin: https://github.com/matrix-org/matrix-rust-components-kotlin
- Matrix Rust Components Swift: https://github.com/matrix-org/matrix-rust-components-swift
- Element X Android: https://github.com/element-hq/element-x-android
- Element X iOS: https://github.com/element-hq/element-x-ios
- Matrix Dart SDK package: https://pub.dev/packages/matrix
- Matrix Dart SDK repository: https://github.com/famedly/matrix-dart-sdk
