import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/core/widgets/custom_text_field.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/auth/domain/models/user_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final user = _authController.user.value;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _bioController.text = user.bio ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final currentUser = _authController.user.value;
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          name: _nameController.text.trim(),
          bio: _bioController.text.trim(),
        );
        await _authController.updateUserData(updatedUser);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final user = _authController.user.value;
            if (user == null) return const CircularProgressIndicator();

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.name?.substring(0, 1).toUpperCase() ??
                                      user.email.substring(0, 1).toUpperCase(),
                                  style: AppTheme.headlineLarge.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    label: 'Name',
                    hint: 'Enter your name',
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Bio',
                    hint: 'Tell us about yourself',
                    controller: _bioController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),
                  Obx(() => ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : _updateProfile,
                        child: _authController.isLoading.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Text('Update Profile'),
                      )),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
} 