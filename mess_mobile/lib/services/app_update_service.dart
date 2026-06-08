import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_release_policy.dart';

enum StoreUpdateKind { none, optional, required }

class StoreUpdateCheck {
  const StoreUpdateCheck({
    required this.kind,
    required this.currentBuild,
    required this.policy,
  });

  final StoreUpdateKind kind;
  final int currentBuild;
  final AppReleasePolicy policy;

  String get storeUrl {
    if (!kIsWeb && Platform.isAndroid) return policy.storeUrlAndroid;
    if (!kIsWeb && Platform.isIOS) return policy.storeUrlIos;
    return '';
  }

  String get targetVersionLabel => policy.latestVersionLabel;
}

/// Store updates driven by Firestore `appConfig/release` and native store APIs.
/// Small changes without a new binary: use Firestore config / feature flags only.
/// Big changes: raise min/latest build in Firestore and ship a new store release.
class AppUpdateService {
  AppUpdateService._();
  static final instance = AppUpdateService._();

  var _checking = false;

  Future<AppReleasePolicy> fetchReleasePolicy() async {
    try {
      final snap = await FirebaseFirestore.instance.doc('appConfig/release').get();
      return AppReleasePolicy.fromMap(snap.data());
    } catch (_) {
      return AppReleasePolicy.defaults();
    }
  }

  Future<int> currentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 1;
  }

  Future<String> currentVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<StoreUpdateCheck> checkStoreUpdate() async {
    if (kIsWeb) {
      return StoreUpdateCheck(
        kind: StoreUpdateKind.none,
        currentBuild: 1,
        policy: AppReleasePolicy.defaults(),
      );
    }

    final policy = await fetchReleasePolicy();
    final build = await currentBuildNumber();
    final isAndroid = Platform.isAndroid;
    final minBuild = policy.minBuildFor(isAndroid: isAndroid);
    final latestBuild = policy.latestBuildFor(isAndroid: isAndroid);

    StoreUpdateKind kind;
    if (build < minBuild) {
      kind = StoreUpdateKind.required;
    } else if (build < latestBuild) {
      kind = StoreUpdateKind.optional;
    } else {
      kind = StoreUpdateKind.none;
    }

    return StoreUpdateCheck(
      kind: kind,
      currentBuild: build,
      policy: policy,
    );
  }

  /// Fetch release policy and compare against the installed build.
  Future<StoreUpdateCheck> runUpdateCycle() async {
    if (_checking) {
      return checkStoreUpdate();
    }
    _checking = true;
    try {
      return await checkStoreUpdate();
    } finally {
      _checking = false;
    }
  }

  /// Android: background download via Play Core (user may still need to confirm).
  Future<bool> tryAndroidFlexibleUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
    } catch (_) {
      // Play Store not available (sideload / emulator).
    }
    return false;
  }

  Future<void> openStoreListing(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
