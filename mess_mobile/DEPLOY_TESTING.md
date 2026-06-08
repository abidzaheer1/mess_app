# Deploy Alpha Mess for testing (Android & iOS)

> **Publishing to Play Store / App Store + auto-updates:** see [PUBLISHING.md](PUBLISHING.md)

Project: `mess_mobile` · Firebase: `mess-df58f`

## Prerequisites

1. Flutter SDK installed (`flutter doctor`)
2. Firebase CLI logged in (`firebase login`)
3. Firestore rules deployed:
   ```powershell
   cd c:\Users\Mohammed.Abidzaheer\Abid\301_mess_app
   firebase deploy --only firestore
   ```

---

## Android (APK for testers)

### One-time setup
```powershell
cd mess_mobile
flutter pub get
```

Ensure `android/app/google-services.json` exists (from Firebase Console → Project settings → Android app).

### Build release APK
```powershell
cd mess_mobile
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Share this file with testers (email, Drive, etc.) or use **Firebase App Distribution**:

```powershell
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app YOUR_ANDROID_FIREBASE_APP_ID `
  --groups testers
```

(Find app ID in Firebase Console → Project settings → Your apps → Android.)

### Install on device
Enable **Install unknown apps**, then open the APK on the phone.

---

## iOS (TestFlight / ad-hoc)

**Requires a Mac** with Xcode and an Apple Developer account ($99/year).

### One-time setup
1. Firebase Console → add iOS app → download `GoogleService-Info.plist` → place in `ios/Runner/`
2. Open `ios/Runner.xcworkspace` in Xcode
3. Set **Team**, **Bundle Identifier**, enable **Signing**

### Build & upload to TestFlight
```bash
cd mess_mobile
flutter build ipa --release
```

Then upload via Xcode **Organizer** or:
```bash
xcrud altool --upload-app -f build/ios/ipa/*.ipa -t ios -u YOUR_APPLE_ID
```

Invite testers in **App Store Connect → TestFlight**.

---

## Web (quick test)
```powershell
cd mess_mobile
flutter run -d chrome --web-port=8080
```

---

## What testers should verify

- [ ] Login / join mess / admin approve join
- [ ] Add expense with receipt photo
- [ ] Chat: type message → **Send** button appears → message sends
- [ ] Monthly settlement card on Dashboard → detailed analytics + PDF
- [ ] Events: create, join, add event expense
- [ ] Grocery rotation in Admin settings

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Chat permission denied | Redeploy Firestore rules |
| Can't send chat | Hot restart app; ensure you're a mess member |
| Overlapping + buttons | Hot restart after latest build |
| iOS build fails | Open Xcode, fix signing & pods (`pod install`) |
