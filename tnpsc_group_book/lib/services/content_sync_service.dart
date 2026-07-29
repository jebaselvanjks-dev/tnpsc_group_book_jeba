import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      var userBox = Hive.box(HiveService.userBoxName);
      
      // AI_OPTIMIZATION: Check content version before syncing 20 docs
      // If version matches, we skip all reads.
      try {
        final configDoc = await FirebaseFirestore.instance.collection('settings').doc('content_metadata').get();
        if (configDoc.exists) {
          int serverVersion = configDoc.data()?['version'] ?? 0;
          int localVersion = userBox.get('local_content_version', defaultValue: -1) as int;
          
          if (serverVersion <= localVersion) {
            AppLog.d("FIRESTORE_OPT: Content is already up to date (v$localVersion). Skipping Sync.");
            await userBox.put('is_initial_sync_done', true);
            return;
          }
          
          // Store the new version to skip future syncs
          await userBox.put('local_content_version', serverVersion);
        }
      } catch (e) {
        AppLog.d("FIRESTORE_OPT: Could not fetch content_metadata, proceeding with full sync.");
      }

      AppLog.d("AI_DEBUG: Starting Silent Background Content Sync...");
      
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
