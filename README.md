# RAID Shard Mercy Counter

A modern, high-performance Flutter application for tracking "mercy" counters (pity system) in RAID: Shadow Legends. Designed for both Desktop (Windows, macOS) and Mobile (Android).

## Key Features

- **Modern UI/UX**: Professional dark theme with glassmorphism effects, elastic animations, and high-quality assets.
- **Multi-Shard Support**: Tracks Ancient, Void, Sacred, and Primal (Mythical/Legendary) shards.
- **Hero Guides**: Integrated library of hero builds and guides synced with external sources.
- **Export/Import**: Full data portability via JSON files.
- **Multilingual**: Support for English, Russian, and Ukrainian.
- **Pity Pulse**: Visual feedback when you're close to a guaranteed legendary pull.

## Tech Stack

- **Flutter 3.x**: Cross-platform development.
- **Google Fonts**: Inter & Outfit for typography.
- **Glassmorphism**: Backdrop filters and custom gradients.
- **Elastic Animations**: Smooth transitions and interactive feedback.

## Commands

```powershell
flutter pub get
flutter run -d windows
flutter run -d android
flutter test
flutter analyze
```

## Maintenance

The project includes several PowerShell scripts for data synchronization:
- `refresh_guides.ps1`: Updates the hero guides library.
- `sync_guides.ps1`: Synchronizes assets with local data.

---
*Disclaimer: All RAID: Shadow Legends assets are property of Plarium. This is an unofficial fan project.*
