import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/subject.dart';
import 'firestore_service.dart';
import 'hive_service.dart';

class ContentSyncService {
  static final FirestoreService _firestoreService = FirestoreService();

  static Future<bool> isSyncRequired() async {
    var box = Hive.box(HiveService.userBoxName);
    return !(box.get('is_initial_sync_done', defaultValue: false) as bool);
  }

  static Future<void> performInitialSync() async {
    try {
      debugPrint("AI_DEBUG: Starting Silent Background Content Sync...");
      var userBox = Hive.box(HiveService.userBoxName);
      
      for (var subject in tnpscSubjects) {
        // 1. Sync Questions
        debugPrint("AI_DEBUG: Syncing Questions for: ${subject.titleEn}");
        await _firestoreService.getSubjectQuestions(subject.titleEn, forceRefresh: true);

        // 2. Sync Study Material
        debugPrint("AI_DEBUG: Syncing Material for: ${subject.titleEn}");
        await _firestoreService.getStudyMaterial(subject.titleEn, forceRefresh: true);
      }

      await userBox.put('is_initial_sync_done', true);
      debugPrint("AI_DEBUG: Silent Initial Content Sync Completed Successfully!");
    } catch (e) {
      debugPrint("AI_DEBUG: Silent Initial Content Sync Failed: $e");
    }
  }
}
