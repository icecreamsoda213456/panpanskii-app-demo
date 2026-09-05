# Panpanskii 1.0.9 release checklist

Tapos na ang mahirap na parte. Ito na lang ang natitira.

| Item | Value |
| --- | --- |
| Version | `1.0.9` |
| versionCode | `10` |
| Tag | `v1.0.9` |
| APK | `build\app\outputs\flutter-apk\app-release.apk` |
| Laki | 105 MB (110,044,608 bytes) |
| SHA-256 | `1232b6c4673fe74d0b6081c78166164a4ea12ac6ae2f828e4d5869ae4766899e` |

---

## 1. I-push ang source commit

Naka-commit na ang code bilang `24bac02` sa `main`. I-push mo lang:

```powershell
git push origin main
```

## 2. Gumawa ng GitHub release

Pumunta sa https://github.com/icecreamsoda213456/panpanskii-app-updates/releases
at pindutin ang **Draft a new release**.

- **Choose a tag** -> i-type ang `v1.0.9` -> **Create new tag: v1.0.9 on publish**
- **Release title**: `Panpanskii 1.0.9`
- **Describe this release**:

```text
Tidier Home screen

- Home no longer repeats what the More tab already lists
- Home keeps Today Together, Quick Actions and Next Together
- One card on Home now opens the More tab
- More tab groups everything else into Connect, Memories and Reflect
```

- **Attach binaries**: i-drag ang APK na ito:

```text
C:\Users\HpProbook\Documents\panpanskii_app\build\app\outputs\flutter-apk\app-release.apk
```

  Mahalaga: `app-release.apk` dapat ang pangalan ng file. Yan ang hinahanap ng
  `apkUrl` sa manifest. Huwag palitan.

- Iwanan na naka-check ang **Set as the latest release**.
- Pindutin ang **Publish release**.

## 3. I-update ang manifest

Sa https://github.com/icecreamsoda213456/panpanskii-app-updates/blob/main/update_manifest.json
pindutin ang lapis (edit), burahin lahat, at i-paste ito:

```json
{
  "version": "1.0.9",
  "versionCode": 10,
  "apkUrl": "https://github.com/icecreamsoda213456/panpanskii-app-updates/releases/latest/download/app-release.apk",
  "title": "Tidier Home screen",
  "message": "Home is calmer now, and nothing shows up twice.",
  "changes": [
    "Home no longer repeats what the More tab already lists",
    "Home keeps Today Together, Quick Actions and Next Together",
    "One card on Home now opens the More tab",
    "More tab groups everything else into Connect, Memories and Reflect"
  ],
  "forceUpdate": false,
  "sha256": "1232b6c4673fe74d0b6081c78166164a4ea12ac6ae2f828e4d5869ae4766899e"
}
```

Commit message: `Update version and release notes in manifest`, tapos **Commit changes**.

Nakahanda na rin ang parehong JSON sa `release_1.0.9_manifest.json` dito sa
project kung mas gusto mong i-copy mula doon.

## 4. Sundin ang pagkakasunod-sunod

I-publish muna ang release bago i-update ang manifest. Kapag baligtad, may
maikling sandali na sinasabi ng manifest na `1.0.9` na ang bago pero `1.0.8`
pa ang nakukuha ng `releases/latest/download`, kaya babagsak ang SHA-256 check
at hindi mag-i-install ang update.

## 5. I-verify

Buksan ang app sa parehong telepono. Pagkatapos mag-load ng Home, dapat lumabas
ang update dialog na "Tidier Home screen". Kung ayaw lumabas:

- Tingnan kung `1.0.9` na ang laman ng
  https://raw.githubusercontent.com/icecreamsoda213456/panpanskii-app-updates/main/update_manifest.json
  (minsan may ilang minutong cache ang raw.githubusercontent).
- Siguraduhing `app-release.apk` talaga ang pangalan ng na-upload na asset.
