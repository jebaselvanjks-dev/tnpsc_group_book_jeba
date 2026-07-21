import 'package:hive/hive.dart';
import '../models/subject.dart';
import '../utils/app_log.dart';
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
      AppLog.d("AI_DEBUG: Starting Silent Background Content Sync...");
      var userBox = Hive.box(HiveService.userBoxName);
      
      for (var subject in tnpscSubjects) {
        // 1. Sync Questions
        AppLog.d("AI_DEBUG: Syncing Questions for: ${subject.titleEn}");
        await _firestoreService.getSubjectQuestions(subject.titleEn, forceRefresh: true);
        
        // Brief yield between calls to reduce pressure
        await Future.delayed(const Duration(milliseconds: 500));

        // 2. Sync Study Material
        AppLog.d("AI_DEBUG: Syncing Material for: ${subject.titleEn}");
        await _firestoreService.getStudyMaterial(subject.titleEn, forceRefresh: true);
        
        // Brief yield between subjects
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      await userBox.put('is_initial_sync_done', true);
      AppLog.d("AI_DEBUG: Silent Initial Content Sync Completed Successfully!");
    } catch (e) {
      AppLog.e("AI_DEBUG: Silent Initial Content Sync Failed: $e");
    }
  }
}
