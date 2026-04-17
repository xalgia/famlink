# Research

Use this page for market notes, technical comparisons, links, and summarized findings.

## Findings

- Matrix supports stored audio messages through `m.audio`, which fits FamLink's voice-note-only transport.
- The clarified product does not need true live audio transport. Live mode is an auto-play behavior for newly received voice notes.
- Synapse can serve as the Matrix homeserver for users, rooms, events, media, and push integration.
- Native iOS/Android with Matrix Rust SDK bindings appears to be the strongest long-term Matrix/E2EE path.
- Flutter with `matrix-dart-sdk` remains viable for a prototype, especially because v1 no longer requires WebRTC or true live media. It still needs validation around encryption, media, push, background behavior, and native audio handling.
- The mobile OSes should not be treated as reliable arbitrary-background-audio playback surfaces. Auto-play should be promised for active/listening states, with notification/history fallback otherwise.

## References

- Matrix Client-Server API: https://spec.matrix.org/latest/client-server-api/
- Matrix `m.audio`: https://spec.matrix.org/latest/client-server-api/#maudio
- Matrix account data: https://spec.matrix.org/latest/client-server-api/#put_matrixclientv3useruseridaccount_datatype
- Matrix pushers: https://spec.matrix.org/latest/client-server-api/#post_matrixclientv3pushersset
- Matrix Push Gateway API: https://spec.matrix.org/latest/push-gateway-api/
- Synapse docs: https://element-hq.github.io/synapse/latest/
- Synapse configuration docs: https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html
- Matrix Rust SDK: https://github.com/matrix-org/matrix-rust-sdk
- Matrix Rust Components Kotlin: https://github.com/matrix-org/matrix-rust-components-kotlin
- Matrix Rust Components Swift: https://github.com/matrix-org/matrix-rust-components-swift
- Element X Android: https://github.com/element-hq/element-x-android
- Element X iOS: https://github.com/element-hq/element-x-ios
- Matrix Dart SDK package: https://pub.dev/packages/matrix
- Matrix Dart SDK repository: https://github.com/famedly/matrix-dart-sdk
- Apple notification sounds: https://developer.apple.com/documentation/usernotifications/unnotificationsound
- Android notification channels: https://developer.android.com/develop/ui/views/notifications/channels

## Assumptions To Validate

- `matrix-dart-sdk` can satisfy the exact encrypted voice-note flow on iOS and Android.
- Flutter audio recording/playback plugins can meet the desired hold-to-talk and auto-play behavior with acceptable native customization.
- Matrix Rust SDK bindings are practical for a small native app team, not just large Element-style clients.
- Synapse push behavior is reliable enough for family voice-note notifications.
- Families understand "live mode" as automatic playback when available, not guaranteed real-time transmission.
