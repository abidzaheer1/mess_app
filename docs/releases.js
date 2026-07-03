(function () {
  const REPO = 'abidzaheer1/mess_app';
  const RELEASES_BASE = 'https://github.com/' + REPO + '/releases';
  const API = 'https://api.github.com/repos/' + REPO + '/releases/latest';
  const LATEST_APK = RELEASES_BASE + '/latest/download/app-release.apk';
  const WEB_APP_URL = 'app/';

  // Set when TestFlight or App Store is live (overrides web app install button)
  const IOS_STORE_URL = '';

  const btnAndroid = document.getElementById('btn-android');
  const btnIos = document.getElementById('btn-ios');
  const androidVersion = document.getElementById('android-version');
  const iosVersion = document.getElementById('ios-version');
  const githubVersion = document.getElementById('github-version');
  const releaseStatus = document.getElementById('release-status');

  function findAsset(assets, extensions) {
    if (!assets || !assets.length) return null;
    return assets.find(function (a) {
      if (!a.name) return false;
      const lower = a.name.toLowerCase();
      return extensions.some(function (ext) {
        return lower.endsWith(ext);
      });
    });
  }

  function enableAndroid(href, label, versionText) {
    androidVersion.textContent = versionText;
    btnAndroid.textContent = label;
    btnAndroid.href = href;
    btnAndroid.removeAttribute('aria-disabled');
  }

  function enableIos(tag) {
    if (IOS_STORE_URL) {
      iosVersion.textContent = tag + ' · App Store';
      btnIos.textContent = 'Download on App Store';
      btnIos.href = IOS_STORE_URL;
    } else {
      iosVersion.textContent = tag + ' · Web app';
      btnIos.textContent = 'Open & install on iPhone';
      btnIos.href = WEB_APP_URL;
    }
    btnIos.removeAttribute('aria-disabled');
  }

  function setFallbackDownloads() {
    enableAndroid(LATEST_APK, 'Download app-release.apk', 'Latest release');
    enableIos('Latest');
    githubVersion.textContent = 'GitHub Releases';
    releaseStatus.hidden = false;
    releaseStatus.className = 'release-status';
    releaseStatus.textContent =
      'Android: install the APK directly. iPhone: open the web app in Safari, then Share → Add to Home Screen.';
  }

  function setNoRelease() {
    androidVersion.textContent = 'No release yet';
    btnAndroid.textContent = 'View releases on GitHub';
    btnAndroid.href = RELEASES_BASE;
    btnAndroid.removeAttribute('aria-disabled');
    enableIos('Pending');
    githubVersion.textContent = 'Create a release to enable downloads';
    releaseStatus.hidden = false;
    releaseStatus.className = 'release-status warn';
    releaseStatus.textContent =
      'No GitHub Release found yet. iPhone users can still install via the web app button above.';
  }

  setFallbackDownloads();

  fetch(API)
    .then(function (res) {
      if (res.status === 404) {
        setNoRelease();
        return null;
      }
      if (!res.ok) throw new Error('API ' + res.status);
      return res.json();
    })
    .then(function (release) {
      if (!release) return;

      const tag = release.tag_name || release.name || 'Latest';
      const apk = findAsset(release.assets, ['.apk']);

      githubVersion.textContent = tag + ' · ' + (release.published_at || '').slice(0, 10);
      enableIos(tag);

      if (apk) {
        enableAndroid(
          apk.browser_download_url,
          'Download ' + apk.name,
          tag + ' · ' + formatSize(apk.size)
        );
      } else {
        enableAndroid(LATEST_APK, 'Download app-release.apk', tag + ' (no APK attached)');
      }

      releaseStatus.hidden = false;
      releaseStatus.className = 'release-status';
      releaseStatus.textContent =
        'Android ' +
        tag +
        ': one-tap APK install. iPhone ' +
        tag +
        ': open web app → Safari → Share → Add to Home Screen.';
    })
    .catch(function () {
      setFallbackDownloads();
    });

  function formatSize(bytes) {
    if (!bytes) return '';
    if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }
})();
