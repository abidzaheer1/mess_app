# Deploy Alpha Mess to Netlify (mess.asxora.io)

## One-time setup (~5 min)

### 1. Log in to Netlify
```powershell
netlify login
```
Approve in the browser when prompted.

### 2. Create the site (linked to this repo)
**Option A — Netlify dashboard (recommended)**
1. Open [app.netlify.com](https://app.netlify.com)
2. **Add new site → Import an existing project → GitHub**
3. Choose repo **`abidzaheer1/mess_app`**
4. Build settings are read from `netlify.toml` automatically
5. Deploy

**Option B — CLI**
```powershell
cd c:\Users\Mohammed.Abidzaheer\Abid\301_mess_app
netlify init
```
Follow prompts: create new site, connect to GitHub.

### 3. Add custom subdomain
1. Netlify → your site → **Domain management → Add a domain**
2. Enter **`mess.asxora.io`**
3. Netlify shows a DNS target like `your-site-name.netlify.app`

### 4. DNS at asxora.io
Where you manage DNS for **asxora.io** (Netlify, Cloudflare, etc.):

| Type  | Name | Value                    |
|-------|------|--------------------------|
| CNAME | mess | `your-site.netlify.app`  |

Wait a few minutes for SSL (Netlify provisions HTTPS automatically).

### 5. GitHub Actions deploy (optional, faster builds)
1. Netlify → **User settings → Applications → Personal access tokens** → create token
2. Netlify → site → **Site configuration → General → Site ID**
3. GitHub repo → **Settings → Secrets → Actions** → add:
   - `NETLIFY_AUTH_TOKEN` = your token
   - `NETLIFY_SITE_ID` = site ID

Pushes to `main` will then deploy via `.github/workflows/netlify.yml`.

---

## Firebase Auth (required for sign-in)

Add each web host to **Firebase Console → Authentication → Settings → Authorized domains**, or run:

```powershell
node scripts/update-firebase-auth-domains.mjs
```

Current domains include `mess.asxora.io`, `alpha-mess-app.netlify.app`, and `abidzaheer1.github.io`.

---

## Live URLs

| Platform | URL |
|----------|-----|
| **iPhone web app** | https://mess.asxora.io |
| **Landing / Android APK** | https://abidzaheer1.github.io/mess_app |

## iPhone install
1. Open **https://mess.asxora.io** in Safari
2. **Share → Add to Home Screen**

## Android install
Download APK from the GitHub Pages site or Releases.
