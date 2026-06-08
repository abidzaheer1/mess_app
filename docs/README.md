# Alpha Mess — GitHub Pages site

Landing page with features and download buttons for GitHub Releases.

**Live URL (after enabling Pages):** https://abidzaheer1.github.io/mess_app/

## Enable GitHub Pages

1. Repo → **Settings** → **Pages**
2. **Build and deployment** → Source: **GitHub Actions**
3. Push to `main` — workflow `.github/workflows/pages.yml` deploys `docs/`

## Attach Android APK to a release

```powershell
cd mess_mobile
flutter build apk --release
```

Then on GitHub → **Releases** → **Draft a new release** → tag `v1.0.0` → upload `build/app/outputs/flutter-apk/app-release.apk`.

The download button on the site updates automatically via the GitHub API.

## iOS App Store link

When TestFlight or App Store is live, set `IOS_STORE_URL` in `docs/releases.js`.
