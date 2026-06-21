# Captures d'écran App Store — SombaTeka

## Tailles requises (iPhone)

| Appareil | Résolution | Obligatoire |
|----------|------------|-------------|
| iPhone 6.7" | 1290 × 2796 | Oui (min. 3) |
| iPhone 6.5" | 1284 × 2778 | Oui (min. 3) |
| iPhone 5.5" | 1242 × 2208 | Legacy (optionnel) |

## Simulateur iOS (Mac)

```bash
cd mobile
open -a Simulator
flutter run --release --dart-define=ST_API_BASE_URL=https://api.sombateka.cd

# Captures : Cmd+S dans le Simulator
# Ou :
xcrun simctl io booted screenshot store/ios/screenshots/6.7/01-home.png
```

## Écrans à capturer

Identiques à Play Store — voir `store/play/SCREENSHOTS.md`.

## Organisation

```
mobile/store/ios/screenshots/
  6.7/
    01-home.png
    02-detail.png
    03-search.png
  6.5/
    ...
```

## App Store Connect

App → App Store → Screenshots → iPhone 6.7" Display → Upload
