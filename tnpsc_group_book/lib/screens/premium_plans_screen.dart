import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/payment_config.dart';
import '../services/payment_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/hive_service.dart';

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isPaying = false;
  String? _activePrice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentService.init(
        onSuccess: _onPaymentSuccess,
        onError: _onPaymentError,
      );
    });
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    _paymentService.markCheckoutClosed();
    if (!mounted || _activePrice == null) return;

    final plan = PremiumPlanInfo.fromPrice(_activePrice!);
    try {
      await PaymentService.activateSubscription(
        plan: plan,
        paymentId: response.paymentId,
        orderId: response.orderId,
        signature: response.signature,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _activePrice = null;
        });
        _showMessage(
          AppLanguage.languageNotifier.value == 'ta'
              ? 'பேமெண்ட் வெற்றி, ஆனால் சந்தா சேமிப்பில் பிழை. Support-ஐ தொடர்பு கொள்ளுங்கள்.'
              : 'Payment succeeded but subscription save failed. Contact support.',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) return;
    final ta = AppLanguage.languageNotifier.value == 'ta';
    final price = _activePrice!;
    final planTitle = _planTitle(price, ta);
    setState(() {
      _isPaying = false;
      _activePrice = null;
    });
    _showSubscriptionSuccessDialog(context, planTitle, price, ta);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _paymentService.markCheckoutClosed();
    if (!mounted) return;
    final ta = AppLanguage.languageNotifier.value == 'ta';
    setState(() {
      _isPaying = false;
      _activePrice = null;
    });
    if (response.code != Razorpay.PAYMENT_CANCELLED) {
      _showMessage(PaymentService.failureMessage(response, ta), isError: true);
    }
  }

  String _planTitle(String price, bool ta) {
    switch (price) {
      case '49':
        return ta ? 'தொடக்க பாஸ்' : 'Starter Pass';
      case '99':
        return ta ? 'புரோ பாஸ்' : 'Pro Pass';
      case '259':
        return ta ? 'எலைட் பாஸ்' : 'Elite Pass';
      default:
        return ta ? 'பிரீமியம்' : 'Premium';
    }
  }

  Future<void> _handleSubscribe({
    required String price,
    required String displayTitle,
    required bool ta,
  }) async {
    if (_isPaying) return;

    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage(
        ta ? 'பேமெண்ட் செய்ய முதலில் உள்நுழையவும்' : 'Please sign in before subscribing',
        isError: true,
      );
      return;
    }

    if (!PaymentConfig.isConfigured) {
      _showSetupKeyDialog(ta);
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    final cached = HiveService.getCachedUserData();

    setState(() {
      _isPaying = true;
      _activePrice = price;
    });

    final plan = PremiumPlanInfo.fromPrice(price);
    final started = await _paymentService.startPayment(
      plan: plan,
      displayTitle: displayTitle,
      userName: cached?['name']?.toString() ?? user.displayName,
      userEmail: user.email,
      userPhone: cached?['phone']?.toString(),
    );

    if (!started && mounted) {
      setState(() {
        _isPaying = false;
        _activePrice = null;
      });
      _showMessage(
        ta
            ? 'பேமெண்ட் பக்கம் திறக்கவில்லை. Internet & Razorpay Key ID சரிபார்க்கவும்.'
            : 'Payment page did not open. Check internet and Razorpay Key ID.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryColor,
      ),
    );
  }

  void _showSetupKeyDialog(bool ta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          ta ? 'Razorpay Key வேண்டும்' : 'Razorpay Key Required',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textMainColor,
          ),
        ),
        content: Text(
          PaymentConfig.configurationMessage(ta: ta),
          style: GoogleFonts.outfit(
            fontSize: 14,
            height: 1.4,
            color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              ta ? 'சரி' : 'OK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final ta = lang == 'ta';

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0A1128), const Color(0xFF101F42), const Color(0xFF0F2D59)]
                    : [const Color(0xFFF4F6F9), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    floating: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      titlePadding: const EdgeInsets.only(bottom: 16),
                      title: SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: AppTheme.secondaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                ta ? 'பிரீமியம் சந்தாக்கள்' : 'Premium Plans',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                  shadows: isDark
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      background: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.secondaryColor, AppTheme.accentColor],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryColor.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Text(
                                ta ? 'VIP உறுப்பினர்' : 'VIP MEMBERSHIP',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black87,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                ta
                                    ? 'உங்கள் அரசு தேர்வு தயாரிப்பை வேகப்படுத்துங்கள்!'
                                    : 'Accelerate your government exam preparation today!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildPlanCard(
                          context: context,
                          isDark: isDark,
                          title: ta ? 'தொடக்க பாஸ்' : 'Starter Pass',
                          price: '49',
                          period: ta ? '1 மாதம்' : '1 Month',
                          ta: ta,
                          features: [
                            ta ? '1 மாதம் செயல்படும் சந்தா' : 'Active for 1 month',
                            ta ? 'ஒரு நாளைக்கு 10 குரூப் தேர்வுகள் (Room Match)' : '10 Room Matches per day',
                          ],
                          gradientColors: [const Color(0xFF5A75A4), const Color(0xFF384F7C)],
                          isPopular: false,
                        ),
                        const SizedBox(height: 24),
                        _buildPlanCard(
                          context: context,
                          isDark: isDark,
                          title: ta ? 'புரோ பாஸ்' : 'Pro Pass',
                          price: '99',
                          period: ta ? '1 மாதம்' : '1 Month',
                          ta: ta,
                          features: [
                            ta ? 'ஒரு நாளைக்கு 10 குரூப் தேர்வுகள் (Room Match)' : '10 Room Matches per day',
                            ta ? 'முற்றிலும் விளம்பரங்கள் இல்லாத ஆப் அனுபவம்' : '100% Ad-Free app experience',
                            ta ? 'அனைத்து TNPSC மாதிரி தேர்வுகள் & இதர தேர்வுகள்' : 'Full access to all TNPSC Mock Tests & Exams',
                          ],
                          gradientColors: [const Color(0xFF0F2D59), const Color(0xFF0A1128)],
                          isPopular: false,
                        ),
                        const SizedBox(height: 24),
                        _buildPlanCard(
                          context: context,
                          isDark: isDark,
                          title: ta ? 'எலைட் பாஸ்' : 'Elite Pass',
                          price: '259',
                          period: ta ? '3 மாதங்கள்' : '3 Months',
                          ta: ta,
                          features: [
                            ta ? 'ஒரு நாளைக்கு 10 குரூப் தேர்வுகள் (Room Match)' : '10 Room Matches per day',
                            ta ? 'முற்றிலும் விளம்பரங்கள் இல்லாத ஆப் அனுபவம்' : '100% Ad-Free learning environment',
                            ta ? 'அனைத்து TNPSC மாதிரி தேர்வுகள் & இதர தேர்வுகள்' : 'Full access to all TNPSC Mock Tests & Exams',
                          ],
                          gradientColors: [AppTheme.secondaryColor, const Color(0xFFB8860B)],
                          isPopular: true,
                          buttonTextColor: Colors.black,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String price,
    required String period,
    required bool ta,
    required List<String> features,
    required List<Color> gradientColors,
    required bool isPopular,
    Color? buttonTextColor,
  }) {
    final isThisPlanLoading = _isPaying && _activePrice == price;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? [gradientColors.first.withOpacity(0.2), gradientColors.last.withOpacity(0.3)]
              : [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isPopular
              ? AppTheme.secondaryColor.withOpacity(0.5)
              : gradientColors.first.withOpacity(isDark ? 0.3 : 0.15),
          width: isPopular ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 14, color: Colors.black),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        ta ? 'சிறந்த மதிப்பு' : 'BEST VALUE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textMainColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹$price',
                      style: GoogleFonts.outfit(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: isPopular
                            ? AppTheme.secondaryColor
                            : (isDark ? Colors.white : AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ $period',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: isDark ? Colors.white60 : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  thickness: 1.5,
                ),
                const SizedBox(height: 20),
                ...features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPopular
                                ? AppTheme.secondaryColor.withOpacity(0.15)
                                : Colors.green.withOpacity(0.12),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: isPopular ? AppTheme.secondaryColor : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              height: 1.3,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPaying && !isThisPlanLoading
                        ? null
                        : () => _handleSubscribe(price: price, displayTitle: title, ta: ta),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular
                          ? AppTheme.secondaryColor
                          : (isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor),
                      foregroundColor: isPopular
                          ? Colors.black87
                          : (isDark ? Colors.white : Colors.white),
                      elevation: isPopular ? 8 : 1,
                      shadowColor: isPopular ? AppTheme.secondaryColor.withOpacity(0.4) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: !isPopular && isDark
                            ? BorderSide(color: Colors.white.withOpacity(0.15))
                            : BorderSide.none,
                      ),
                    ),
                    child: isThisPlanLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black87),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payment_rounded,
                                size: 18,
                                color: isPopular ? Colors.black87 : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  ta ? 'இப்போதே பே செய்க' : 'Pay Now',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionSuccessDialog(BuildContext context, String planTitle, String price, bool ta) {
    showDialog(
      context: context,
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF101F42) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.transparent,
              ),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.secondaryColor.withOpacity(0.15),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppTheme.secondaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  ta ? 'வாழ்த்துகள்!' : 'Congratulations!',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: isDark ? Colors.white : AppTheme.textMainColor,
                  ),
                ),
              ],
            ),
            content: Text(
              ta
                  ? '$planTitle (₹$price) வெற்றிகரமாக செலுத்தப்பட்டது! பிரீமியம் அம்சங்கள் திறக்கப்பட்டன.'
                  : 'Your $planTitle (₹$price) payment was successful! Premium features are now unlocked.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
            ),
            actions: [
              Center(
                child: SizedBox(
                  width: 140,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      ta ? 'தொடரவும்' : 'Continue',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          ),
        );
      },
    );
  }
}
