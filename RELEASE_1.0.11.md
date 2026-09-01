# Release Checklist — v1.0.11 (versionCode 12)

## Anong bago sa release na ito
- Naayos ang pag-draw sa Widget Notes canvas (hindi na sinusunggab ng scroll ang daliri; naayos rin ang live-painting bug, hindi na sumusunod sa lumang stroke kapag nagpapadala ng bagong draw)
- Mas malaki ang default size ng home-screen widget (3x3 cells, 140dp minimum)
- **Widget Notes push (FCM)** - awtomatikong lumalabas sa home-screen widget ng partner ang hand-drawn note: data-only FCM > background isolate > i-download ang latest PNG > i-refresh ang widget
- **Supabase Edge Function 500 fix** - ang `send-push-notification` ay bumalik na ng 200: maling `grant_type` URN (`oauth:grant-type`, hindi `oauth2:grant-type`); at nawawalang `type` variable
- **Public PNG URLs** - gumagamit na ng permanenteng public URL, hindi na signed URLs na nag-e-expire sa isang linggo;
- **Diagnostics screen** - bagong tool para i-check ang push setup (long-press ang "Widget Note" tile sa More > "Widget Notes Diagnostics"): 200/400/401/403/500 status, sent/failed count, partner push-token status;
- **Widget background** - nanatiling **pure black `#121212`** (hindi itinuloy ang lavender, base sa feedback;)

## Preparation (TAPOS NA — hindi mo na kailangang gawin)
- [x] `pubspec.yaml` → `version: 1.0.11+12`
- [x] Analyzer clean (No issues found)
- [x] Binago ang `note_widget_info.xml`, `widget_note_background.xml`, `widget_note_layout.xml`, `widget_note_canvas_screen.dart`

## Step 1 — Manual Build (IKAW ang tatakbo nito)
```powershell
cd C:\Users\HpProbook\Documents\panpanskii_app
flutter build apk --release
```
Expected output: `build\app\outputs\flutter-apk\app-release.apk`

## Step 2 — Kunin ang SHA-256 hash (para sa manifest)
```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256 | Select-Object -ExpandProperty Hash
```
**Result:** `17F173CB42F7C3DFE5CFB671E04417BF6F6698BBEE87132F2EA8834F18D7C026` (105.7 MB)

## Step 3 — Commit + Push
```powershell
git add -A
git commit -m "Fix canvas drawing, enlarge widget, calming lavender background — bump to 1.0.11+12"
git push origin main
```

## Step 4 — Publish sa GitHub Releases
Repo: https://github.com/icecreamsoda213456/panpanskii-app-updates/releases
- **Tag:** `v1.0.11` (Create new tag on publish, target: main)
- **Title:** `Panpanskii 1.0.11`
- **Notes:**
```markdown
## What's New 🎉

### ✍️ Widget Notes Fixes
- Drawing on the note canvas now works perfectly — no more fighting with scrolling
- The home-screen widget is now bigger by default (3x3 cells)
- New calming lavender-night widget background 🌙
- Softer spinner and text colors on the widget
```
- I-attach ang **`app-release.apk`** (huwag palitan ang filename)
- Iwanang naka-check ang **Set as the latest release** → **Publish release**

## Step 5 — I-update ang `update_manifest.json`
I-paste sa `panpanskii-app-updates` repo → `update_manifest.json` → Edit.
**Palitan ang `sha256` ng aktwal na hash mula sa Step 2:**
```json
{
  "version": "1.0.11",
  "versionCode": 12,
  "apkUrl": "https://github.com/icecreamsoda213456/panpanskii-app-updates/releases/latest/download/app-release.apk",
  "title": "Widget Notes fixes",
  "message": "Drawing is fixed and the widget got a calmer look.",
  "changes": [
    "Fixed drawing on the Widget Notes canvas",
    "Bigger default widget size on the home screen",
    "New calming lavender widget background",
    "Softer spinner and text colors"
  ],
  "forceUpdate": false,
  "sha256": "17F173CB42F7C3DFE5CFB671E04417BF6F6698BBEE87132F2EA8834F18D7C026"
}
```
→ **Commit changes**

## Step 6 — Test
1. I-install ang APK sa parehong phones (o mag-open ng app sa old version — lalabas ang update dialog)
2. Buksan ang Widget Notes → subukang mag-draw — dapat sunud-sunuran na
3. I-drag ang widget sa home screen — mas malaki na at lavender ang background
