# Release Checklist - v1.0.12 (versionCode 13)

## Anong bago sa release na ito

- **Widget Notes end-to-end push (FCM)** - awtomatikong lumalabas sa home-screen widget ng partner ang hand-drawn note. Mag-send ka lang, at kusa at agad na mag-u-update ang widget ng partner basta may internet - parang messaging lang, walang manwal na i-save o i-open ang app.

  - Data-only FCM push > background isolate > syncLatest > widget refresh (kahit sarado ang app)
  - Awtomatikong session recovery sa background isolate para laging gumana ang auto-refresh
- **Supabase Edge Function 500 fix** - ang `send-push-notification` ay bumalik na ng 200: maling `grant_type` URN (`oauth:grant-type`, hindi `oauth2:grant-type`), nawawalang `type` variable, at awtomatikong pagbubura ng mga patay na FCM token (404 NotRegistered)para laging malinis ang delivery
- **Live drawing fix** - nakikita mo na agad ang iyong stroke habang iginuguhit mo ito(hindi mo na kailangang magpalit ng kulay para lumabas ang iginuhit mo)
- **Diagnostics screen** - bagong tool para i-check ang buong widget-note chain sa phone (More > long-press ang "Widget Note" tile > "Widget Notes Diagnostics"): Account, approved, partner note, PNG HTTP 200 download test, at widget data(
- **Public PNG URLs** - permanenteng public URL na(hindi na signed URLs na nag-e-expire sa isang linggo(
- Mas malaki ang home-screen widget(3x3 cells, 140dp minimum) at pure black `#121212` background(hindi itinuloy ang lavender)

## Preparation (TAPOS NA na - hindi mo na kailangang gawin(
- [x] `pubspec.yaml` > `version: 1.0.12+13`(
- [x] Lauhat ng mga fix ay naka-commit na sa `main` (
- [x] Edge Function ay naka-deploy na sa Supabase(CLI/dashboard)

## Step  ̈1 - Manual Build(IKAW ang tatakbo nito)
```powershell
cd C:\Users\HpProbook\Documents\panpanskii_app
flutter build apk --release
```
Expected output: `build\app\outputs\flutter-apk\app-release.apk`

## Step Step  ̈2 - Kunin ang SHA-256 hash
```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256 | Select-Object -ExpandProperty Hash
```
- Ilagay ang resulta sa `release_1.0.12_manifest.json` > `sha256`(
- (O i-edit ang `update_manifest.json` sa panpanskii-app-updates repo nang direkta()

## Step Step  ̈3 - Commit + Push(main repo)
```powershell
git add -A
git commit -m "Release prep 1.0.12+13"
git push origin main
```

## Step Step Step  ̈4 - Publish sa GitHub Releases
Repo: https://github.com/icecreamsoda213456/panpanskii-app-updates/releases
- **Tag:** `v1.0.12` (Create new tag on publish, target: main)
- **Title:** `Panpanskii 1.0.12`(
- **Notes:**
```markdown
What's New
### 1.0.12 - Widget Notes: gumagana na nang buo!
- Drawing: live na ang stroke habang nagdo-draw ka
- Push: awtomatikong nag-a-update ang partner's widget pagka-send mo - parang messaging lang
- Fixed ang Supabase Edge Function 500 (plus auto-delete ng patay na FCM tokens)
- Mas malaki ang widget(3x3 cells, pure black background)

```
- I-attach ang **`app-release.apk`** (huwag palitan ang filename)(
- Iwanang naka-check ang **Set as the latest release** > **Publish release**

## Step Step Step  ̈5 - I-update ang `update_manifest.json`(
- I-paste ang laman ng **`release_1.0.12_manifest.json`** (pagkatapos ilagay ang hash) sa:
  https://github.com/icecreamsoda213456/panpanskii-app-updates/blob/main/update_manifest.json
- > **Edit** > i-replace ang buong laman > **Commit changes**
- Mahalaga: ang `versionCode: 13` ay dapat nasa manifest(kasi ang update check ng app ay **versionCode** ang inihahambing(`manifest.versionCode <= installedVersionCode` = walang update)))

## Step Step Step  ̈6 - Test sa dalawang phone
1. I-install ang bagong APK sa parehong phone(
2. Mag-send ng note mula sa KOALA > dapat kusa at agad na lumabas sa widget ni PANDA(kahit sarado ang app, basta may internet(
3\. Mag-send mula sa PANDA > dapat kusa at agad na lumabas sa widget ni KOALA(
4. I-check: More > long-press "Widget Note" > Widget Notes Diagnostics > dapat lahat green(