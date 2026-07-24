class Series {
  final String id;
  String name;
  final String folderPath;

  // Release tracking (all optional; older backups omit these).
  // sourceType: 'mangadex' | 'scrape' | null (untracked).
  // sourceRef:  MangaDex series id/URL, or a page URL to scrape.
  // latestChapter: last fetched latest-released chapter number (may be
  //   fractional, e.g. 1186.5), cached so the grid renders without network.
  // lastCheckedAt: ISO timestamp of the last successful fetch.
  String? sourceType;
  String? sourceRef;
  num? latestChapter;
  String? lastCheckedAt;

  Series({
    required this.id,
    required this.name,
    required this.folderPath,
    this.sourceType,
    this.sourceRef,
    this.latestChapter,
    this.lastCheckedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folderPath': folderPath,
        if (sourceType != null) 'sourceType': sourceType,
        if (sourceRef != null) 'sourceRef': sourceRef,
        if (latestChapter != null) 'latestChapter': latestChapter,
        if (lastCheckedAt != null) 'lastCheckedAt': lastCheckedAt,
      };

  factory Series.fromJson(Map<String, dynamic> json) => Series(
        id: json['id'] as String,
        name: json['name'] as String,
        folderPath: json['folderPath'] as String,
        sourceType: json['sourceType'] as String?,
        sourceRef: json['sourceRef'] as String?,
        latestChapter: json['latestChapter'] as num?,
        lastCheckedAt: json['lastCheckedAt'] as String?,
      );
}
