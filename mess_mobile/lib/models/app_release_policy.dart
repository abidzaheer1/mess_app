class AppReleasePolicy {
  const AppReleasePolicy({
    required this.minBuildAndroid,
    required this.minBuildIos,
    required this.latestBuildAndroid,
    required this.latestBuildIos,
    this.minVersionLabel = '1.0.0',
    this.latestVersionLabel = '1.0.0',
    this.storeUrlAndroid = '',
    this.storeUrlIos = '',
    this.releaseNotes = '',
  });

  factory AppReleasePolicy.defaults() => const AppReleasePolicy(
        minBuildAndroid: 1,
        minBuildIos: 1,
        latestBuildAndroid: 1,
        latestBuildIos: 1,
      );

  factory AppReleasePolicy.fromMap(Map<String, dynamic>? data) {
    if (data == null) return AppReleasePolicy.defaults();
    int readInt(String key, int fallback) => (data[key] as num?)?.toInt() ?? fallback;
    return AppReleasePolicy(
      minBuildAndroid: readInt('minBuildAndroid', 1),
      minBuildIos: readInt('minBuildIos', 1),
      latestBuildAndroid: readInt('latestBuildAndroid', 1),
      latestBuildIos: readInt('latestBuildIos', 1),
      minVersionLabel: data['minVersionLabel'] as String? ?? '1.0.0',
      latestVersionLabel: data['latestVersionLabel'] as String? ?? '1.0.0',
      storeUrlAndroid: data['storeUrlAndroid'] as String? ?? '',
      storeUrlIos: data['storeUrlIos'] as String? ?? '',
      releaseNotes: data['releaseNotes'] as String? ?? '',
    );
  }

  final int minBuildAndroid;
  final int minBuildIos;
  final int latestBuildAndroid;
  final int latestBuildIos;
  final String minVersionLabel;
  final String latestVersionLabel;
  final String storeUrlAndroid;
  final String storeUrlIos;
  final String releaseNotes;

  int minBuildFor({required bool isAndroid}) => isAndroid ? minBuildAndroid : minBuildIos;

  int latestBuildFor({required bool isAndroid}) => isAndroid ? latestBuildAndroid : latestBuildIos;

  String storeUrlFor({required bool isAndroid}) => isAndroid ? storeUrlAndroid : storeUrlIos;
}
