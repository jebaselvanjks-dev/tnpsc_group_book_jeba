import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'hive_service.dart';
import 'firestore_service.dart';
import '../utils/app_log.dart';

class RewardService {
  static RewardedAd? _rewardedAd;
  static bool _isRewardedLoaded = false;
  static bool _isRewardedLoading = false;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoaded = false;
  static bool _isInterstitialLoading = false;

  /// Change Ad Ids

  /// Rewarded Ad IDs
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String realRewardedId = 'ca-app-pub-9952621231526514/2142313722';

  /// Interstitial Ad IDs
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String realInterstitialId = 'ca-app-pub-9952621231526514/2643599886'; // Replace with real ID later

  // Toggle this for testing
  static bool useTestAds = false;

  static String get rewardedAdUnitId => useTestAds ? testRewardedId : realRewardedId;
  static String get interstitialAdUnitId => useTestAds ? testInterstitialId : realInterstitialId;

  /// NEW: Handles User Consent (UMP) and initializes Mobile Ads
  static Future<void> handleConsentAndInit() async {
    if (HiveService.isAdFree()) return;
    
    final Completer<void> completer = Completer<void>();
    AppLog.d('AI_DEBUG: [UMP] Requesting consent information update...');
    
    final params = ConsentRequestParameters();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          AppLog.d('AI_DEBUG: [UMP] Consent info update success.');
          
          ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? formError) async {
              if (formError != null) {
                AppLog.e('AI_DEBUG: [UMP] Consent form error: ${formError.message}');
              } else {
                AppLog.d('AI_DEBUG: [UMP] Consent gathering completed.');
              }

              // Check if we can request ads according to the consent gathered
              if (await ConsentInformation.instance.canRequestAds()) {
                _initializeMobileAds();
              } else {
                AppLog.d('AI_DEBUG: [UMP] Consent gathered but ads NOT allowed by user.');
              }
              if (!completer.isCompleted) completer.complete();
            },
          );
        },
        (FormError error) {
          AppLog.e('AI_DEBUG: [UMP] Consent info update failed: ${error.message}');
          _initializeMobileAds(); // Fallback to try loading ads anyway
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      AppLog.e('AI_DEBUG: [UMP] Error in consent flow: $e');
      _initializeMobileAds();
      if (!completer.isCompleted) completer.complete();
    }
    
    return completer.future;
  }

  static void _initializeMobileAds() async {
    AppLog.d('AI_DEBUG: Initializing MobileAds SDK...');
    try {
      await MobileAds.instance.initialize();
      AppLog.d('AI_DEBUG: MobileAds initialized successfully.');
      
      // Load initial ads immediately after initialization
      loadRewardedAd();
      loadInterstitialAd();
    } catch (e) {
      AppLog.e('AI_DEBUG: MobileAds initialization failed: $e');
    }
  }

  static void loadRewardedAd() {
    if (HiveService.isAdFree()) return;
    if (_isRewardedLoaded || _isRewardedLoading) return;

    _isRewardedLoading = true;
    AppLog.d('AI_DEBUG: Loading Rewarded Ad (ID: $rewardedAdUnitId)');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
          _isRewardedLoading = false;
          AppLog.d('AI_DEBUG: Rewarded Ad Loaded Successfully');
        },
        onAdFailedToLoad: (err) {
          _isRewardedLoaded = false;
          _isRewardedLoading = false;
          AppLog.d('AI_DEBUG: Rewarded Ad failed to load: $err');
          
          // Simple retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () => loadRewardedAd());
        },
      ),
    );
  }

  static void loadInterstitialAd() {
    if (HiveService.isAdFree()) return;
    if (_isInterstitialLoaded || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    AppLog.d('AI_DEBUG: Loading Interstitial Ad (ID: $interstitialAdUnitId)');

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          AppLog.d('AI_DEBUG: Interstitial Ad Loaded Successfully');
        },
        onAdFailedToLoad: (err) {
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          AppLog.d('AI_DEBUG: Interstitial Ad failed to load: $err');

          // Simple retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () => loadInterstitialAd());
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

  /// Deducts points from the user's total
  static Future<void> deductPoints(int points) async {
    try {
      if (points <= 0) return;
      final fs = FirestoreService();
      await fs.incrementUserPoints(-points);
      AppLog.d('AI_DEBUG: Deducted $points points');
    } catch (e) {
      AppLog.d('AI_DEBUG: Failed to deduct points: $e');
    }
  }

  static void showRewardAdIfAllowed({
    required VoidCallback onRewardEarned, 
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
      onFailure: onRewardEarned,
    );
  }

  static void showRewardAd({required VoidCallback onRewardEarned, VoidCallback? onFailure}) {
    if (HiveService.isAdFree()) {
      AppLog.d('AI_DEBUG: Ad-Free enabled, granting reward directly.');
      onRewardEarned();
      return;
    }

    if (_isRewardedLoaded && _rewardedAd != null) {
      AppLog.d('AI_DEBUG: Showing Rewarded Ad...');
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          AppLog.d('AI_DEBUG: Rewarded Ad dismissed by user.');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd(); // Pre-load next ad
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          AppLog.d('AI_DEBUG: Rewarded Ad failed to show: $err');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd();
          if (onFailure != null) onFailure(); else onRewardEarned(); 
        },
      );
      
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        AppLog.d('AI_DEBUG: User earned reward from Ad.');
        onRewardEarned();
      });
    } else {
      AppLog.d('AI_DEBUG: Rewarded Ad not ready yet, attempting to load and show.');
      loadRewardedAd();
      
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_isRewardedLoaded && _rewardedAd != null) {
          AppLog.d('AI_DEBUG: Ad loaded after retry, showing now.');
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedLoaded = false;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              AppLog.d('AI_DEBUG: Ad failed to show after retry: $err');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedLoaded = false;
              loadRewardedAd();
              if (onFailure != null) onFailure(); else onRewardEarned();
            },
          );
          _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            onRewardEarned();
          });
        } else {
          AppLog.d('AI_DEBUG: Ad still not ready after 2.5s delay. Skipping.');
          if (onFailure != null) onFailure(); else onRewardEarned();
        }
      });
    }
  }

  static void showInterstitialAd({required VoidCallback onDismissed}) {
    if (HiveService.isAdFree()) {
      onDismissed();
      return;
    }

    if (_isInterstitialLoaded && _interstitialAd != null) {
      AppLog.d('AI_DEBUG: Showing Interstitial Ad...');
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          AppLog.d('AI_DEBUG: Interstitial Ad dismissed.');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialLoaded = false;
          loadInterstitialAd(); // Pre-load next
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          AppLog.d('AI_DEBUG: Interstitial Ad failed to show: $err');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onDismissed();
        },
      );
      _interstitialAd!.show();
    } else {
      AppLog.d('AI_DEBUG: Interstitial Ad not ready. Pre-loading for next time.');
      loadInterstitialAd();
      onDismissed();
    }
  }

  // Helper to watch two rewarded ads sequentially and award total points
  static Future<void> watchTwoAdsAndAwardPoints() async {
    await Future<void>.sync(() => showRewardAdIfAllowed(onRewardEarned: () {}));
    await Future<void>.sync(() => showRewardAdIfAllowed(onRewardEarned: () {}));
  }
}
