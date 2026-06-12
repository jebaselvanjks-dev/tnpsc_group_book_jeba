import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';

class StudyMaterial {
  final String subject;
  final String category;
  final List<MaterialItem> material;
  final DateTime? lastUpdated;

  StudyMaterial({
    required this.subject,
    required this.category,
    required this.material,
    this.lastUpdated,
  });

  factory StudyMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyMaterial(
      subject: data['subject'] ?? '',
      category: data['category'] ?? '',
      material: (data['material'] as List? ?? [])
          .map((item) => MaterialItem.fromMap(item))
          .toList(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject': subject,
      'category': category,
      'material': material.map((item) => item.toMap()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class MaterialItem {
  final int id;
  final String tamil;
  final String english;

  MaterialItem({
    required this.id,
    required this.tamil,
    required this.english,
  });

  String get content =>
      AppLanguage.languageNotifier.value == 'ta' ? tamil : english;

  factory MaterialItem.fromMap(Map<String, dynamic> map) {
    return MaterialItem(
      id: map['id'] ?? 0,
      tamil: map['tamil'] ?? '',
      english: map['english'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tamil': tamil,
      'english': english,
    };
  }
}
