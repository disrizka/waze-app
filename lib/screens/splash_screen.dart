import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/splash_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<SplashProvider>(
        context,
        listen: false,
      ).handleAutoLogin(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Shimmer.fromColors(
          baseColor: AppColors.primary.withOpacity(0.6),
          highlightColor: Colors.greenAccent.withOpacity(0.8),
          direction: ShimmerDirection.ltr,
          period: const Duration(seconds: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/wave_up_logo.png', fit: BoxFit.contain),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
