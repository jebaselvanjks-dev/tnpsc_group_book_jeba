import 'package:tnpsc_group_book/utils/app_language.dart';

class CurrentAffairsPoint {
  final String? id;
  final String titleEn;
  final String titleTa;
  final String contentEn;
  final String contentTa;
  final String date;
  final String category;
  final DateTime? createdAt;

  CurrentAffairsPoint({
    this.id,
    required this.titleEn,
    required this.titleTa,
    required this.contentEn,
    required this.contentTa,
    required this.date,
    required this.category,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title_en': titleEn,
      'title_ta': titleTa,
      'content_en': contentEn,
      'content_ta': contentTa,
      'date': date,
      'category': category,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory CurrentAffairsPoint.fromMap(Map<String, dynamic> map) {
    return CurrentAffairsPoint(
      id: map['id'],
      titleEn: map['title_en'] ?? '',
      titleTa: map['title_ta'] ?? '',
      contentEn: map['content_en'] ?? '',
      contentTa: map['content_ta'] ?? '',
      date: map['date'] ?? '',
      category: map['category'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }

  String get displayTitle => AppLanguage.languageNotifier.value == 'ta' ? titleTa : titleEn;
  String get displayContent => AppLanguage.languageNotifier.value == 'ta' ? contentTa : contentEn;
}
