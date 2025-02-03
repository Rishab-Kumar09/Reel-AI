import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/views/login_view.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/views/signup_view.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/feed_view.dart';
import 'package:flutter_firebase_app_new/features/profile/presentation/views/profile_view.dart';
import 'package:flutter_firebase_app_new/core/routes/app_routes.dart';

class AppPages {
  static const initial = Routes.login;

  static final routes = [
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.signup,
      page: () => const SignupView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.feed,
      page: () => const FeedView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.profile,
      page: () => const ProfileView(),
      transition: Transition.fadeIn,
    ),
  ];
} 