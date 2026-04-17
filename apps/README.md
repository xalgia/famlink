# Apps

FamLink is organized as a monorepo so mobile clients can live together with shared tooling and local development services.

Current app:

- `android/`: Kotlin Android app scaffold using Jetpack Compose and the Matrix Rust Android SDK artifact.

Possible future app folders:

- `ios/`: native iOS client if we adopt the Matrix Rust Swift components directly.
- `flutter/`: Flutter client if we decide to wrap Matrix Rust through native plugins or validate another approach.
