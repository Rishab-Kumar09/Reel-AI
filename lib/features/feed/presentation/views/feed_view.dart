import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            onPressed: () => authController.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Obx(() {
          final user = authController.user.value;
          if (user == null) return const CircularProgressIndicator();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome,',
                style: AppTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                user.name ?? user.email,
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Feed view coming soon...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          );
        }),
      ),
    );
  }
} 