(function () {
  const REPO = 'abidzaheer1/mess_app';
  const RELEASES_BASE = 'https://github.com/' + REPO + '/releases';
  const API = 'https://api.github.com/repos/' + REPO + '/releases/latest';
  const LATEST_APK = RELEASES_BASE + '/latest/download/app-release.apk';
  const LATEST_IPA = RELEASES_BASE + '/latest/download/app-release.ipa';

  // Set when TestFlight or App Store is live
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

  function enableIos(href, label, versionText) {
    iosVersion.textContent = versionText;
    btnIos.textContent = label;
    btnIos.href = href;
    btnIos.removeAttribute('aria-disabled');
  }

  function setFallbackDownloads() {
    enableAndroid(LATEST_APK, 'Download app-release.apk', 'Latest release');
    if (IOS_STORE_URL) {
      enableIos(IOS_STORE_URL, 'Download on App Store', 'App Store');
    } else {
      enableIos(LATEST_IPA, 'Download app-release.ipa', 'Latest release');
    }
    githubVersion.textContent = 'GitHub Releases';
    releaseStatus.hidden = false;
    releaseStatus.className = 'release-status';
    releaseStatus.textContent =
      'Direct download links are active. Android installs from the APK. iPhone/iPad: download the IPA on a computer, then install with AltStore or Sideloadly (free Apple ID).';
  }

  function setNoRelease() {
    androidVersion.textContent = 'No release yet';
    btnAndroid.textContent = 'View releases on GitHub';
    btnAndroid.href = RELEASES_BASE;
    btnAndroid.removeAttribute('aria-disabled');
    iosVersion.textContent = 'No release yet';
    btnIos.textContent = 'View releases on GitHub';
    btnIos.href = RELEASES_BASE;
    btnIos.removeAttribute('aria-disabled');
    githubVersion.textContent = 'Create a release to enable downloads';
    releaseStatus.hidden = false;
    releaseStatus.className = 'release-status warn';
    releaseStatus.textContent =
      'No GitHub Release found yet. Publish a release with APK and IPA attached.';
  }

  function setupIosFromRelease(release, tag) {
    if (IOS_STORE_URL) {
      enableIos(IOS_STORE_URL, 'Download on App Store', tag + ' · App Store');
      return;
    }

    const ipa = findAsset(release.assets, ['.ipa']);
    if (ipa) {
      enableIos(
        ipa.browser_download_url,
        'Download ' + ipa.name,
        tag + ' · ' + formatSize(ipa.size)
      );
      return;
    }

    enableIos(LATEST_IPA, 'Download app-release.ipa', tag + ' · IPA pending');
  }

  // Always wire direct latest/download links first so buttons work even if the API is slow.
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
      const ipa = findAsset(release.assets, ['.ipa']);

      githubVersion.textContent = tag + ' · ' + (release.published_at || '').slice(0, 10);
      setupIosFromRelease(release, tag);

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
      if (apk && ipa) {
        releaseStatus.textContent =
          'Latest release ' +
          tag +
          ' — Android APK and iOS IPA ready. On iPhone: sideload the IPA with AltStore or Sideloadly.';
      } else if (apk) {
        releaseStatus.className = 'release-status warn';
        releaseStatus.textContent =
          'Release ' + tag + ' has Android APK but no iOS IPA yet.';
      } else {
        releaseStatus.className = 'release-status warn';
        releaseStatus.textContent =
          'Release ' + tag + ' is missing download assets.';
      }
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
