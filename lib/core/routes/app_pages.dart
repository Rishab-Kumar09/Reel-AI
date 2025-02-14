import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/views/login_view.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/views/signup_view.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/feed_view.dart';
import 'package:flutter_firebase_app_new/features/profile/presentation/views/profile_view.dart';
import 'package:flutter_firebase_app_new/features/navigation/presentation/views/main_navigation_view.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/video_player_view.dart';
import 'package:flutter_firebase_app_new/core/routes/app_routes.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';

class MainNavigationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthController>(() => AuthController());
  }
}

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
      page: () => const MainNavigationView(),
      binding: MainNavigationBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.profile,
      page: () => const ProfileView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.videoPlayer,
      page: () => const VideoPlayerView(),
      transition: Transition.fadeIn,
    ),
  ];
}
