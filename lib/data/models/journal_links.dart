class JournalLinks {
  final String? main;
  final String? translated;
  final String? other;

  const JournalLinks({
    this.main,
    this.translated,
    this.other,
  });

  factory JournalLinks.fromJson(Map<String, dynamic> json) {
    return JournalLinks(
      main: json['main'] as String?,
      translated: json['translated'] as String?,
      other: json['other'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'main': main,
      'translated': translated,
      'other': other,
    };
  }

  bool get hasAny => main != null || translated != null || other != null;

  List<LinkItem> get allLinks {
    final links = <LinkItem>[];
    if (main != null) links.add(LinkItem('main', 'Сайт журнала', main!));
    if (translated != null) links.add(LinkItem('translated', 'Переводная версия', translated!));
    if (other != null) links.add(LinkItem('other', 'Зеркальный URL', other!));
    return links;
  }
}

class LinkItem {
  final String key;
  final String label;
  final String url;

  const LinkItem(this.key, this.label, this.url);
}