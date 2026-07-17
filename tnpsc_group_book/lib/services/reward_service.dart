import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'hive_service.dart';
import 'firestore_service.dart';
import '../utils/app_log.dart';

class RewardService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoaded = false;

  /// Change Ad Id

  /// Test Rewarded Ad ID
  static const String testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// REAL Rewarded Ad ID
  static const String realAdUnitId = 'ca-app-pub-9952621231526514/2142313722';

  // Toggle this for testing
  static bool useTestAds = false;

  static String get adUnitId => useTestAds ? testAdUnitId : realAdUnitId;

  static void loadRewardedAd() {
    AppLog.d('AI_DEBUG: Loading Rewarded Ad (ID: $adUnitId)');
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          AppLog.d('AI_DEBUG: Rewarded Ad Loaded Successfully');
        },
        onAdFailedToLoad: (err) {
          _isAdLoaded = false;
          AppLog.d('AI_DEBUG: Rewarded Ad failed to load: $err');
          if (err.message.contains('403')) {
             AppLog.d('AI_DEBUG: ERROR 403: This usually means the AdMob account is not approved or the Ad Unit ID/Package Name mismatch.');
          }
        },
      ),
    );
  }

  /// Adds reward points to the user's total
  static Future<void> addPoints(int points, {bool syncToCloud = false}) async {
    try {
      if (points <= 0) return;
      await HiveService.addPoints(points);
      AppLog.d('AI_DEBUG: Added $points points via HiveService');
      
      if (syncToCloud) {
        final fs = FirestoreService();
        await fs.incrementUserPoints(points);
      }
    } catch (e) {
      AppLog.d('AI_DEBUG: Failed to add points: $e');
    }
  }

  static void showRewardAdIfAllowed({
    required Function onRewardEarned, 
    int? fixedRewardAmount, 
    bool useLimit = false
  }) {
    if (useLimit && !HiveService.canWatchRewardAdToday()) {
      AppLog.d('AI_DEBUG: Daily limit reached for settings ad.');
      onRewardEarned(); 
      return;
    }
    
    // Calculate dynamic reward amount for quiz ads if not a fixed settings reward
    int rewardAmount = fixedRewardAmount ?? 0;
    if (fixedRewardAmount == null) {
      int watchCount = HiveService.getQuizAdWatchCountToday();
      if (watchCount == 0) rewardAmount = 15;
      else if (watchCount == 1) rewardAmount = 10;
      else if (watchCount == 2) rewardAmount = 5;
      else rewardAmount = 0;
    }

    if (HiveService.isAdFree()) {
      addPoints(rewardAmount, syncToCloud: true);
      if (useLimit) HiveService.incrementRewardAdWatchCountToday();
      if (fixedRewardAmount == null) HiveService.incrementQuizAdWatchCountToday();
      onRewardEarned();
      return;
    }

    // Show ad and award points when completed
    showRewardAd(
      onRewardEarned: () async {
        await addPoints(rewardAmount, syncToCloud: true);
        if (useLimit) await HiveService.incrementRewardAdWatchCountToday();
        if (fixedRewardAmount == null) await HiveService.incrementQuizAdWatchCountToday();
        onRewardEarned();
      },
      onFailure: () {
        onRewardEarned();
      }
    );
  }

  static void showRewardAd({required Function onRewardEarned, VoidCallback? onFailure}) {
    if (HiveService.isAdFree()) {
      onRewardEarned();
      return;
    }
    if (_isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          loadRewardedAd(); // Load next ad
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          loadRewardedAd();
          if (onFailure != null) onFailure(); else onRewardEarned(); 
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewardEarned();
      });
    } else {
      AppLog.d('AI_DEBUG: Rewarded Ad not ready yet, loading and will retry once.');
      loadRewardedAd();
      
      // AI_DEBUG: Use a single retry to avoid infinite recursion
      Future.delayed(const Duration(seconds: 2), () {
        if (_isAdLoaded && _rewardedAd != null) {
          // One final check before giving up
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              loadRewardedAd();
            },
          );
          _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            onRewardEarned();
          });
        } else {
          AppLog.d('AI_DEBUG: Ad still not ready after 2s, proceeding to failure path.');
          if (onFailure != null) onFailure(); else onRewardEarned();
        }
      });
    }
  }

  // Helper to watch two rewarded ads sequentially and award total points
  static Future<void> watchTwoAdsAndAwardPoints() async {
    await Future<void>.sync(() => showRewardAdIfAllowed(onRewardEarned: () {}));
    await Future<void>.sync(() => showRewardAdIfAllowed(onRewardEarned: () {}));
  }
}
