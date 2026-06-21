# Captures d'écran Play Store — SombaTeka

## Spécifications Google Play

| Type | Taille minimale | Quantité |
|------|-----------------|----------|
| Téléphone | 1080×1920 ou 1440×2560 | **Min. 2**, recommandé 4–8 |
| Tablette 7" | 1200×1920 | Optionnel |
| Tablette 10" | 1600×2560 | Optionnel |

Format : PNG ou JPEG, sans barre de statut simulée si possible.

## Écrans recommandés

1. **Accueil** — grille d'annonces + header
2. **Détail produit** — photos, prix, vendeur
3. **Recherche / filtres**
4. **Publication annonce**
5. **Messagerie**
6. **Profil / vendeur officiel** (si applicable)

## Méthode A — Émulateur Android (recommandé)

```powershell
cd mobile
flutter emulators --launch Pixel_7_API_34   # adapter le nom
flutter run --release --dart-define=ST_API_BASE_URL=https://api.sombateka.cd

# Dans un autre terminal :
.\scripts\capture-screenshots.ps1
```

## Méthode B — Appareil physique

1. Installer l'APK release
2. Naviguer vers chaque écran
3. Captures natives (Power + Volume bas)
4. Transférer vers `store/play/screenshots/phone/`

## Méthode C — adb manuel

```powershell
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png store/play/screenshots/phone/01-home.png
```

## Dossier de sortie

```
mobile/store/play/screenshots/phone/
  01-home.png
  02-detail.png
  03-search.png
  04-messages.png
```

## Play Console

Store presence → Main store listing → Graphics → Phone screenshots → Upload
