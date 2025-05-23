import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/routes/app_routes.dart';
import 'package:flutter_firebase_app_new/features/auth/data/services/auth_service.dart';
import 'package:flutter_firebase_app_new/features/auth/domain/models/user_model.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final Rx<User?> firebaseUser = Rx<User?>(null);
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize with current user if any
    firebaseUser.value = _authService.currentUser;

    // Listen to auth state changes
    ever(firebaseUser, _handleAuthChanged);
    firebaseUser.bindStream(_authService.authStateChanges);

    // Mark as initialized
    isInitialized.value = true;
  }

  void _handleAuthChanged(User? user) async {
    if (!isInitialized.value) return;

    if (user == null) {
      this.user.value = null; // Clear the user data
      // Only navigate to login if we're not already there
      if (Get.currentRoute != Routes.login) {
        Get.offAllNamed(Routes.login);
      }
    } else {
      // Load user data first
      await _loadUserData();
      // Only navigate to feed if we're not already there
      if (Get.currentRoute == Routes.login) {
        Get.offAllNamed(Routes.feed);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      isLoading.value = true;
      user.value = await _authService.getUserData();
    } catch (e) {
      // Suppress PigeonUserDetails errors
      if (!e.toString().contains('PigeonUserDetails')) {
        Get.snackbar(
          'Error',
          'Failed to load user data',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
          colorText: AppTheme.errorColor,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithTestUser() async {
    try {
      isLoading.value = true;
      await _authService.createTestUser();
      Get.snackbar(
        'Success',
        'Signed in successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(milliseconds: 500),
      );
    } catch (e) {
      // Silently handle errors
      print('Test user sign in error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      isLoading.value = true;

      // Check if this is the test account
      if (email == AuthService.testEmail &&
          password == AuthService.testPassword) {
        // First try to create the account
        try {
          await _authService.signUpWithEmail(email, password);
          Get.snackbar(
            'Success',
            'Signed in successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.successColor.withOpacity(0.1),
            colorText: AppTheme.successColor,
            duration: const Duration(milliseconds: 500),
          );
        } catch (e) {
          // If account already exists, try to sign in
          if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
            await _authService.signInWithEmail(email, password);
            Get.snackbar(
              'Success',
              'Signed in successfully',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.successColor.withOpacity(0.1),
              colorText: AppTheme.successColor,
              duration: const Duration(milliseconds: 500),
            );
          } else {
            rethrow;
          }
        }
      } else {
        await _authService.signInWithEmail(email, password);
        Get.snackbar(
          'Success',
          'Signed in successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.successColor.withOpacity(0.1),
          colorText: AppTheme.successColor,
          duration: const Duration(milliseconds: 500),
        );
      }
    } catch (e) {
      // Silently handle errors
      print('Sign in error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      isLoading.value = true;
      await _authService.signUpWithEmail(email, password);
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await _authService.signInWithGoogle();
      Get.snackbar(
        'Success',
        'Signed in successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(milliseconds: 500),
      );
    } catch (e) {
      // Silently handle errors
      print('Google sign in error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await _authService.signOut();
      user.value = null;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      await _authService.resetPassword(email);
      Get.snackbar(
        'Success',
        'Password reset email sent',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateUserData(UserModel userData) async {
    try {
      isLoading.value = true;
      await _authService.updateUserData(userData);
      user.value = userData;
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
