import 'journal_links.dart';

class Journal {
  final int id;
  final String url;
  final List<String> title;
  final List<String> issn;
  final JournalLinks? links;
  final int? level2023;
  final int? level2025;
  final int? level2026;
  final String? state;
  final String? notice;
  final String? dateAccepted;
  final String? dateDiscontinued;

  const Journal({
    required this.id,
    required this.url,
    required this.title,
    required this.issn,
    this.links,
    this.level2023,
    this.level2025,
    this.level2026,
    this.state,
    this.notice,
    this.dateAccepted,
    this.dateDiscontinued,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as int,
      url: json['url'] as String,
      title: (json['title'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      issn: (json['issn'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      links: json['links'] != null ? JournalLinks.fromJson(json['links'] as Map<String, dynamic>) : null,
      level2023: json['level_2023'] as int?,
      level2025: json['level_2025'] as int?,
      level2026: json['level_2026'] as int?,
      state: json['state'] as String?,
      notice: json['notice'] as String?,
      dateAccepted: json['dateAccepted'] as String?,
      dateDiscontinued: json['dateDiscontinued'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'issn': issn,
      'links': links?.toJson(),
      'level_2023': level2023,
      'level_2025': level2025,
      'level_2026': level2026,
      'state': state,
      'notice': notice,
      'dateAccepted': dateAccepted,
      'dateDiscontinued': dateDiscontinued,
    };
  }



  String get primaryTitle => title.isNotEmpty ? title.first : 'Без названия';
  String get secondaryTitle => title.length > 1 ? title[1] : '';
  String get primaryIssn => issn.isNotEmpty ? issn.first : '';
  String get displayIssn => primaryIssn;

  int? get latestLevel => level2026 ?? level2025 ?? level2023;
  int? get highestLevel {
    final levels = [level2023, level2025, level2026].whereType<int>().toList();
    return levels.isNotEmpty ? levels.reduce((a, b) => a > b ? a : b) : null;
  }

  bool get isActive => dateDiscontinued == null;
  bool get hasLinks => links?.hasAny ?? false;
}