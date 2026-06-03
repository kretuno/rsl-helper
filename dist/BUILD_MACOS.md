# macOS build

This project is ready for macOS, including the app icon generated from the legendary shard.

Build on a Mac with Flutter and Xcode installed:

```bash
flutter pub get
flutter build macos --release
```

The built app will be created under:

```text
build/macos/Build/Products/Release/RSL Shard Memory.app
```

Optional DMG packaging can be done from that `.app` on macOS with your preferred DMG/notarization workflow.
