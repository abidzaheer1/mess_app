(function () {
  const REPO = 'abidzaheer1/mess_app';
  const API = 'https://api.github.com/repos/' + REPO + '/releases/latest';
  const RELEASES_URL = 'https://github.com/' + REPO + '/releases';

  // Optional: set when App Store / TestFlight is live
  const IOS_STORE_URL = '';

  const btnAndroid = document.getElementById('btn-android');
  const btnIos = document.getElementById('btn-ios');
  const androidVersion = document.getElementById('android-version');
  const iosVersion = document.getElementById('ios-version');
  const githubVersion = document.getElementById('github-version');
  const releaseStatus = document.getElementById('release-status');

  function findApk(assets) {
    if (!assets || !assets.length) return null;
    return assets.find(function (a) {
      return a.name && a.name.toLowerCase().endsWith('.apk');
    }) || assets.find(function (a) {
      return a.content_type === 'application/vnd.android.package-archive';
    }) || null;
  }

  function setNoRelease() {
    androidVersion.textContent = 'No release yet';
    btnAndroid.textContent = 'Build instructions on GitHub';
    btnAndroid.href = RELEASES_URL;
    btnAndroid.removeAttribute('aria-disabled');
    githubVersion.textContent = 'Create a release to enable downloads';
    releaseStatus.hidden = false;
    releaseStatus.className = 'release-status warn';
    releaseStatus.textContent =
      'No GitHub Release found yet. Publish a release with an APK attached and this page will show a download button automatically.';
  }

  function setupIos() {
    if (IOS_STORE_URL) {
      iosVersion.textContent = 'Available on App Store';
      btnIos.textContent = 'Download on App Store';
      btnIos.href = IOS_STORE_URL;
      btnIos.removeAttribute('aria-disabled');
    } else {
      iosVersion.textContent = 'Coming soon';
      btnIos.textContent = 'Coming soon';
      btnIos.href = '#';
      btnIos.setAttribute('aria-disabled', 'true');
    }
  }

  setupIos();

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
      const apk = findApk(release.assets);

      githubVersion.textContent = tag + ' · ' + (release.published_at || '').slice(0, 10);

      if (apk) {
        androidVersion.textContent = tag + ' · ' + formatSize(apk.size);
        btnAndroid.textContent = 'Download ' + apk.name;
        btnAndroid.href = apk.browser_download_url;
        btnAndroid.removeAttribute('aria-disabled');
        releaseStatus.hidden = false;
        releaseStatus.className = 'release-status';
        releaseStatus.textContent = 'Latest release: ' + tag + (release.name ? ' — ' + release.name : '');
      } else {
        androidVersion.textContent = tag + ' (no APK attached)';
        btnAndroid.textContent = 'View release assets';
        btnAndroid.href = release.html_url || RELEASES_URL;
        btnAndroid.removeAttribute('aria-disabled');
        releaseStatus.hidden = false;
        releaseStatus.className = 'release-status warn';
        releaseStatus.textContent =
          'Release ' + tag + ' exists but has no .apk file. Attach app-release.apk to the GitHub Release.';
      }
    })
    .catch(function () {
      setNoRelease();
    });

  function formatSize(bytes) {
    if (!bytes) return '';
    if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }
})();
