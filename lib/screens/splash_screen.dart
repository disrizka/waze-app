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
          baseColor: AppColors.primary.withOpacity(0.3),
          highlightColor: AppColors.primary.withOpacity(0.6),
          period: const Duration(seconds: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.chat_bubble_outline,
                size: 100,
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Wave Biz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
