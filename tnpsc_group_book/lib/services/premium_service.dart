import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'hive_service.dart';

/// Syncs premium status and clears expired subscription data (Pro/Elite/Starter).
class PremiumService {
  static final _db = FirebaseFirestore.instance;
  static DateTime get _startOfToday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Call on app launch — clears own user premium if expired before today.
  static Future<void> syncCurrentUserPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('PremiumService: sync started for uid=$uid');
    if (uid == null) return;

    try {
      final ref = _db.collection('users').doc(uid);
      // Try fetching from cache first for speed, then sync with server in background
      final snap = await ref.get();
      if (!snap.exists) {
        debugPrint('PremiumService: No user document for uid=$uid');
        return;
      }

      // Convert Firestore data to a mutable map and handle Timestamp fields.
      final rawData = snap.data()! as Map<String, dynamic>;
      debugPrint('PremiumService: raw data fetched: $rawData');
      final data = <String, dynamic>{};
      rawData.forEach((key, value) {
        if (value is Timestamp) {
          data[key] = value.toDate().toIso8601String();
        } else {
          data[key] = value;
        }
      });

      final expiryStr = data['premiumExpiry'] as String?;
      debugPrint('PremiumService: premiumExpiry=$expiryStr, isPremium=${data['isPremium']}');

      if (data['isPremium'] == true && expiryStr != null) {
        try {
          final expiry = DateTime.parse(expiryStr);
          if (!expiry.isAfter(_startOfToday)) {
            await _clearPremiumFields(ref);
            debugPrint('PremiumService: cleared expired premium for $uid');
            return;
          }
        } catch (e) {
          debugPrint('PremiumService: bad expiry $expiryStr');
        }
      }

      await HiveService.cacheUserData(data);
      debugPrint('PremiumService: user data cached for $uid');
    } catch (e) {
      debugPrint('PremiumService.sync: $e');
    }
  }


  static Future<void> _clearPremiumFields(DocumentReference ref) async {
    await ref.set(
      {
        'isPremium': false,
        'premiumPlan': FieldValue.delete(),
        'premiumExpiry': FieldValue.delete(),
        'lastPaymentAt': FieldValue.delete(),
        'lastPaymentId': FieldValue.delete(),
        'lastOrderId': FieldValue.delete(),
        'premiumClearedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final cached = HiveService.getCachedUserData() ?? {};
    cached['isPremium'] = false;
    cached.remove('premiumPlan');
    cached.remove('premiumExpiry');
    cached.remove('lastPaymentAt');
    cached.remove('lastPaymentId');
    cached.remove('lastOrderId');
    await HiveService.cacheUserData(cached);
  }
}
