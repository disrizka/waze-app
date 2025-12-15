// lib/screens/subscription/subscription_payment_success_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SubscriptionPaymentSuccessScreen extends StatelessWidget {
  const SubscriptionPaymentSuccessScreen({
    super.key,
    required this.planName,
    required this.periodLabel,
    required this.amountLabel,
  });

  final String planName;
  final String periodLabel;
  final String amountLabel;

  static const _bgTop = Color(0xFFF7F9FF);

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.black.withOpacity(0.88);
    final subColor = Colors.black.withOpacity(0.62);

    final warmParagraph =
        "Your payment is confirmed and your premium subscription is now active. "
        "Thank you for trusting WaveUp, we hope this helps your business feel more organized, faster, and calmer day to day.";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white],
                  ),
                ),
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // -------- TOP CONTENT --------
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: constraints.maxHeight * 0.38,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 380,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/subscription-page.svg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              Text(
                                "You’re all set",
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Text(
                                warmParagraph,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.55,
                                  color: subColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ✅ Card info plan
                              _PlanInfoCard(
                                planName: planName,
                                periodLabel: periodLabel,
                                amountLabel: amountLabel,
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // -------- BOTTOM CTA --------
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/home',
                                      (r) => false,
                                    );
                                  },
                                  child: const Text(
                                    "Continue",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Enjoy your premium features",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: Colors.black.withOpacity(0.45),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  const _PlanInfoCard({
    required this.planName,
    required this.periodLabel,
    required this.amountLabel,
  });

  final String planName;
  final String periodLabel;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final labelColor = Colors.black.withOpacity(0.55);
    final valueColor = Colors.black.withOpacity(0.88);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF6)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Subscription details",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 12),

          _kv("Plan", planName, labelColor, valueColor),
          const SizedBox(height: 8),
          _kv("Billing period", periodLabel, labelColor, valueColor),
          const SizedBox(height: 8),
          _kv("Total paid", amountLabel, labelColor, valueColor, strong: true),

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.black.withOpacity(0.08)),
          const SizedBox(height: 10),

          Text(
            "You can download your invoice anytime from Subscription History.",
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Colors.black.withOpacity(0.62),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(
    String k,
    String v,
    Color labelColor,
    Color valueColor, {
    bool strong = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              fontSize: 12.5,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            v.isEmpty ? "-" : v,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              color: valueColor,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
