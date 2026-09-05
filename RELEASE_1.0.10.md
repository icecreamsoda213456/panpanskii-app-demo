# Panpanskii 1.0.10 release checklist

| Item | Value |
| --- | --- |
| Version | `1.0.10` |
| versionCode | `11` |
| Tag | `v1.0.10` |
| APK | `build\app\outputs\flutter-apk\app-release.apk` |
| Laki | `105.7 MB` |
| SHA-256 | `0E914C258F491A1117F414930C32E50428136A9BE868DC1A930B6AED32F91D8E` |

---

## 1. I-build ang APK

```powershell
flutter build apk --release
```

## 2. Kunin ang SHA-256

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256 | Select-Object Hash
```

I-copy ang hash (maliit na tip: pwedeng iwanang malapit, tinatanggap din ang
malaking titik) at ilagay sa manifest sa step 5.

## 3. I-push ang source commit sa source repo

```powershell
git add -A
git commit -m "Add widget notes with FCM auto-update and restyle the widget"
git push origin main
```

## 4. Gumawa ng GitHub release

Pumunta sa https://github.com/icecreamsoda213456/panpanskii-app-updates/releases
at pindutin ang **Draft a new release**.

- **Choose a tag** -> i-type ang `v1.0.10` -> **Create new tag: v1.0.10 on publish**
- **Release title**: `Panpanskii 1.0.10`
- **Describe this release**:

```text
Widget Notes and faster updates

- New home-screen widget shows your partner's hand-drawn note
- The widget refreshes on its own using WiFi or mobile data, even when the app is closed
- Draw and send notes from the new Widget Notes screen in the More tab
- Modern black widget card with a loading spinner
- Daily Duo now resets at 6 AM Manila time so both phones agree
- Fixed the tulip plant rendering in Cozy Garden
```

- **Attach binaries**: i-drag ang APK na ito:

```text
C:\Users\HpProbook\Documents\panpanskii_app\build\app\outputs\flutter-apk\app-release.apk
```

  Mahalaga: `app-release.apk` dapat ang pangalan ng file. Yan ang hinahanap ng
  `apkUrl` sa manifest. Huwag palitan.

- Iwanan na naka-check ang **Set as the latest release**.
- Pindutin ang **Publish release**.

## 5. I-update ang manifest

Sa https://github.com/icecreamsoda213456/panpanskii-app-updates/blob/main/update_manifest.json
pindutin ang lapis (edit), burahin lahat, at i-paste ito — **palitan lang ang
`sha256` ng hash mula sa step 2**:

```json
{
  "version": "1.0.10",
  "versionCode": 11,
  "apkUrl": "https://github.com/icecreamsoda213456/panpanskii-app-updates/releases/latest/download/app-release.apk",
  "title": "Widget Notes and faster updates",
  "message": "Your partner's notes now live on your home screen.",
  "changes": [
    "New home-screen widget shows your partner's hand-drawn note",
    "The widget refreshes on its own using WiFi or mobile data",
    "Draw and send notes from the new Widget Notes screen",
    "Daily Duo now resets at 6 AM Manila time",
    "Fixed the tulip plant rendering in Cozy Garden"
  ],
  "forceUpdate": false,
  "sha256": "PASTE_SHA256_HASH_HERE"
}
```

Commit message: `Update version and release notes in manifest`, tapos **Commit changes**.

## 6. Sundin ang pagkakasunod-sunod

I-publish muna ang release (step 4) bago i-update ang manifest (step 5). Kapag
baligtad, may maikling sandali na sinasabi ng manifest na `1.0.10` na ang bago
pero `1.0.9` pa ang nakukuha ng `releases/latest/download`, kaya babagsak ang
SHA-256 check at hindi mag-i-install ang update.

## 7. I-verify

Buksan ang app sa parehong telepono. Pagkatapos mag-load ng Home, dapat lumabas
ang update dialog na "Widget Notes and faster updates". Kung ayaw lumabas:

- Tingnan kung `1.0.10` na ang laman ng
  https://raw.githubusercontent.com/icecreamsoda213456/panpanskii-app-updates/main/update_manifest.json
  (minsan may ilang minutong cache ang raw.githubusercontent).
- Siguraduhing `app-release.apk` talaga ang pangalan ng na-upload na asset.

## 8. Paalala: i-deploy rin ang Edge Function

May binago tayong loogik sa `supabase/functions/send-push-notification/index.ts`
(data-only push para sa `widget_note`) — i-paste at i-deploy iyon sa Supabase
Dashboard, kung hindi pa, hindi mag-a-auto-update ang widget habang sarado ang app.
