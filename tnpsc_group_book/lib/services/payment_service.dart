import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/payment_config.dart';
import 'hive_service.dart';

/// Premium plan metadata used for Razorpay checkout and subscription activation.
class PremiumPlanInfo {
  final String planName;
  final int amountRupees;
  final int durationDays;

  const PremiumPlanInfo({
    required this.planName,
    required this.amountRupees,
    required this.durationDays,
  });

  int get amountInPaise => amountRupees * 100;

  static PremiumPlanInfo fromPrice(String price) {
    switch (price) {
      case '49':
        return const PremiumPlanInfo(planName: 'Starter', amountRupees: 49, durationDays: 30);
      case '99':
        return const PremiumPlanInfo(planName: 'Pro', amountRupees: 99, durationDays: 30);
      case '259':
        return const PremiumPlanInfo(planName: 'Elite', amountRupees: 259, durationDays: 90);
      default:
        return const PremiumPlanInfo(planName: 'Starter', amountRupees: 49, durationDays: 30);
    }
  }
}

class PaymentService {
  Razorpay? _razorpay;
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  /// Initializes Razorpay and registers callbacks. The callbacks are wrapped to reset the processing flag
  /// after a payment succeeds, fails, or an external wallet is selected.
  void init({
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
    void Function(ExternalWalletResponse response)? onExternalWallet,
  }) {
    _razorpay?.clear();
    _razorpay = Razorpay();
    // Wrap callbacks to ensure processing state is cleared
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (resp) {
      _isProcessing = false;
      onSuccess(resp);
    });
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (resp) {
      _isProcessing = false;
      onError(resp);
    });
    _razorpay!.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      (resp) {
        _isProcessing = false;
        if (onExternalWallet != null) {
          onExternalWallet(resp);
        }
      },
    );
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Opens Razorpay checkout on the next frame (required on Android).
  Future<bool> startPayment({
    required PremiumPlanInfo plan,
    required String displayTitle,
    String? userName,
    String? userEmail,
    String? userPhone,
  }) async {
    if (!PaymentConfig.isConfigured) {
      debugPrint('PaymentService: ${PaymentConfig.configurationMessage()}');
      return false;
    }
    if (_razorpay == null || _isProcessing) {
      debugPrint('PaymentService: Razorpay not ready (null=${_razorpay == null}, busy=$_isProcessing)');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isProcessing = true;

    final options = <String, dynamic>{
      'key': PaymentConfig.normalizedKeyId,
      'amount': plan.amountInPaise,
      'currency': 'INR',
      'name': PaymentConfig.appName,
      'description': displayTitle,
      'notes': {
        'plan': plan.planName,
        'user_id': uid,
      },
      'prefill': <String, String>{
        if (userName != null && userName.isNotEmpty) 'name': userName,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        if (userPhone != null && userPhone.isNotEmpty) 'contact': userPhone,
      },
      'theme': <String, String>{'color': '#D4AF37'},
    };

    final completer = Completer<bool>();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        debugPrint('PaymentService: opening Razorpay checkout for ₹${plan.amountRupees}');
        _razorpay!.open(options);
        completer.complete(true);
      } catch (e, stack) {
        debugPrint('PaymentService: open failed — $e\n$stack');
        _isProcessing = false;
        completer.complete(false);
      }
    });

    return completer.future;
  }

  void markCheckoutClosed() {
    _isProcessing = false;
  }

  /// Activates premium after successful Razorpay payment.
  /// Requires secure verifyRazorpayPayment Cloud Function success before updating local state.
  static Future<void> activateSubscription({
    required PremiumPlanInfo plan,
    String? paymentId,
    String? orderId,
    String? signature,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'NOT_SIGNED_IN',
      );
    }

    try {
      debugPrint('PaymentService: Triggering verifyRazorpayPayment Cloud Function');
      final callable = FirebaseFunctions.instance.httpsCallable('verifyRazorpayPayment');
      final response = await callable.call(<String, dynamic>{
        'paymentId': paymentId ?? '',
        'orderId': orderId ?? '',
        'signature': signature ?? '',
        'planName': plan.planName,
      });

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'PAYMENT_VERIFICATION_FAILED',
        );
      }

      debugPrint('PaymentService: Server-side Razorpay verification succeeded.');

      final userData = HiveService.getCachedUserData() ?? {};
      userData['isPremium'] = true;
      userData['premiumPlan'] = data['premiumPlan'] ?? plan.planName;
      userData['premiumExpiry'] = data['premiumExpiry'];
      await HiveService.cacheUserData(userData);
      debugPrint('PaymentService: Hive local subscription updated.');
    } catch (e) {
      debugPrint('PaymentService: Server-side verification failed ($e).');
      rethrow;
    }
  }

  static String failureMessage(PaymentFailureResponse response, bool ta) {
    final code = response.code;
    final message = response.message ?? '';
    if (code == Razorpay.PAYMENT_CANCELLED) {
      return ta ? 'பேமெண்ட் ரத்து செய்யப்பட்டது' : 'Payment was cancelled';
    }
    if (message.toLowerCase().contains('key') || message.toLowerCase().contains('api')) {
      return ta
          ? 'Razorpay Key தவறானது. Dashboard-லிருந்து Key ID சரிபார்க்கவும்.'
          : 'Invalid Razorpay API key. Check Key ID in Razorpay Dashboard.';
    }
    if (message.isNotEmpty) return message;
    return ta ? 'பேமெண்ட் தோல்வி. மீண்டும் முயற்சிக்கவும்.' : 'Payment failed. Please try again.';
  }
}
