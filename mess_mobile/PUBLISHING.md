# Publish Alpha Mess (Android + iOS)

Firebase project: `mess-df58f` · App id: `com.alphamess.mess_mobile`

## Update strategy (built in)

No third-party OTA. Updates use **Firestore** (`appConfig/release`) plus **Google Play** / **App Store**.

| Update type | How | User sees |
|-------------|-----|-----------|
| **Config-only** (copy, limits, feature toggles, remote content) | Change fields in Firestore `appConfig/release` (or other `appConfig` docs) | Nothing — app reads config on launch / resume |
| **Optional store** (new version available) | Raise `latestBuild*` in Firestore | Optional banner; on Android, Play **flexible** in-app update when Play has a newer build |
| **Required store** (breaking / security) | Raise `minBuild*` in Firestore + publish new AAB/IPA | Blocking “Update required” screen → store link |

### What you cannot do (be honest)

- **iOS:** Apple does not allow silent replacement of the app binary outside the App Store. There is no supported “patch the Dart bundle in the background” flow without a store (or enterprise) distribution channel.
- **Android:** Play **flexible** updates still involve Play Core; the user may need to accept a download or restart. It is not guaranteed fully silent.
- **Dart/UI bug fixes** that require new code in the installed APK/IPA → **must** ship a new store build (or accept that only Firestore-driven behavior can change without a release).

Control versions in **Firestore** → `appConfig/release` (see `firebase/app_config_release.json`).

---

## One-time setup

### 1. Firestore release config

```powershell
cd c:\Users\Mohammed.Abidzaheer\Abid\301_mess_app
firebase deploy --only firestore
```

In Firebase Console → Firestore → create document **`appConfig/release`** with fields from `mess_mobile/firebase/app_config_release.json`. Update store URLs after publishing.

### 2. Android signing (Play Store)

```powershell
cd mess_mobile\android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
copy key.properties.example key.properties
# Edit key.properties with your passwords
```

Build release AAB:

```powershell
cd mess_mobile
flutter build appbundle --release
# Output: build\app\outputs\bundle\release\app-release.aab
```

### 3. iOS (App Store / TestFlight)

Requires **Mac**, **Apple Developer** ($99/year), Xcode.

1. Firebase Console → add iOS app if needed → `GoogleService-Info.plist` in `ios/Runner/`
2. Open `ios/Runner.xcworkspace` in Xcode → set **Team**, **Bundle ID** `com.alphamess.mess_mobile`
3. App Store Connect → create app listing
4. Build:

```bash
cd mess_mobile
flutter build ipa --release
```

Upload via Xcode **Organizer** or Transporter → **TestFlight** → production release.

---

## Google Play Store

1. [Google Play Console](https://play.google.com/console) → Create app **Alpha Mess**
2. Complete store listing (screenshots, privacy policy URL, content rating)
3. Upload **AAB** to **Production** or **Internal testing**
4. Copy Play Store URL into Firestore `storeUrlAndroid`

## Apple App Store

1. [App Store Connect](https://appstoreconnect.apple.com) → New app
2. TestFlight beta → then submit for **App Review**
3. Copy App Store URL into Firestore `storeUrlIos`

---

## Releasing a new version

1. Bump `pubspec.yaml`: `version: 1.1.0+2` (name + build number)
2. **Store release** (any Dart/native/plugin change in the binary):
   - `flutter build appbundle --release` (Android) / `flutter build ipa --release` (iOS)
   - Upload to stores
   - Update Firestore `appConfig/release`:
     - `latestBuildAndroid` / `latestBuildIos` → new build number
     - `latestVersionLabel` → e.g. `1.1.0`
3. **Force everyone to update** (breaking change):
   - Set `minBuildAndroid` / `minBuildIos` to the new build number
4. **Change behavior without a new binary** (only where the app already reads Firestore):
   - Edit `appConfig/release` (or related config docs): feature flags, copy, thresholds, URLs
   - Do **not** expect old installs to pick up new Dart code

---

## Firebase App Distribution (beta testers)

Before Play/App Store review:

```powershell
flutter build apk --release
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app YOUR_ANDROID_FIREBASE_APP_ID `
  --groups testers
```

---

## CI (optional)

Tag a release in git; build AAB/IPA on your Mac/CI and upload to stores. No OTA patch step.

---

## Checklist before go-live

- [ ] Firestore rules deployed (`appConfig` readable)
- [ ] `appConfig/release` document created
- [ ] Android upload keystore backed up securely
- [ ] iOS signing + App Store Connect listing
- [ ] Google Sign-In SHA-1 added in Firebase for release keystore
- [ ] Privacy policy URL in store listings
