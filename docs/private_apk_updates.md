# Panpanskii Private APK Updates

Panpanskii checks one configured Google Drive JSON manifest after the
authenticated Home screen is ready. The manifest decides which APK is current,
so future updates do not require changing the manifest URL inside old app
builds.

## One-time setup

1. Make a copy of `update_manifest.example.json` for the live manifest.
2. Upload that JSON file to Google Drive.
3. Set its sharing access so both app users can download it without signing
   into a Google account inside Panpanskii.
4. Convert its share link to a direct download link.
5. Paste that direct manifest URL into
   `lib/config/app_update_config.dart`.
6. Keep the same manifest Drive file for future releases. Replace its contents
   rather than creating a new manifest link.

A common Google Drive direct link format is:

```text
https://drive.google.com/uc?export=download&id=GOOGLE_DRIVE_FILE_ID
```

The file ID is the value between `/d/` and `/view` in a normal Drive share
link.

## Publishing each future update

1. Keep the existing Android `applicationId`.
2. Build the APK with the same signing key used by the installed app.
3. Increase the Flutter build number in `pubspec.yaml`, for example:

```yaml
version: 1.1.0+2
```

Here, `1.1.0` is the display version and `2` becomes Android `versionCode`.

4. Upload the new APK to Google Drive and allow link-based downloading.
5. Put the APK direct download URL in the live manifest `apkUrl`.
6. Put the same display version and build number in the manifest:

```json
{
  "version": "1.1.0",
  "versionCode": 2,
  "apkUrl": "https://drive.google.com/uc?export=download&id=APK_FILE_ID",
  "title": "New Panpanskii Update",
  "message": "We've made our little world even better.",
  "changes": [
    "A new shared feature",
    "Performance improvements",
    "Bug fixes"
  ],
  "forceUpdate": false,
  "sha256": null
}
```

7. Replace the contents of the existing manifest file on Google Drive without
   changing its configured URL.

## Android update identity

Android installs the downloaded APK as an update only when all three are true:

1. The `applicationId` is unchanged.
2. The new APK is signed with the same signing key as the installed APK.
3. The new `versionCode` is greater than the installed `versionCode`.

Do not replace or lose the signing key. A debug-signed installation cannot be
updated by an APK signed with a different release key. Android preserves app
data during a valid package update.

## Optional SHA-256

`sha256` may remain `null`. To enable integrity verification, calculate the
APK's SHA-256 digest and place the 64-character hexadecimal value in the
manifest. Panpanskii rejects the APK when the digest does not match.

## Google Drive download pages

Google Drive may return an HTML confirmation or error page instead of the file,
especially for some large APK links. Panpanskii intentionally rejects HTML and
does not open the installer. Confirm that both direct links download their raw
files without requiring a browser login or confirmation page.
