# Android App

Blank Kotlin Android app for FamLink.

Current stack:

- Android Gradle Plugin 9.
- Built-in AGP Kotlin support.
- Jetpack Compose UI.
- Matrix Rust SDK Android components via `org.matrix.rustcomponents:sdk-android`.

Build:

```sh
ANDROID_HOME=/home/x/Android/Sdk ./gradlew :apps:android:assembleDebug
```

The current screen is intentionally minimal. Voice-note tiles, Matrix login, room setup, recording, upload, and playback will be added after the client spike.
