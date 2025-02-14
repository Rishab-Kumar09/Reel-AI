import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialShareSheet extends StatelessWidget {
  final String twitterPost;
  final String linkedInPost;
  final String facebookPost;

  const SocialShareSheet({
    Key? key,
    required this.twitterPost,
    required this.linkedInPost,
    required this.facebookPost,
  }) : super(key: key);

  Future<void> _shareOnPlatform(String platform, String content) async {
    try {
      // Copy content to clipboard
      await Clipboard.setData(ClipboardData(text: content));

      // Show success message for clipboard
      Get.snackbar(
        'Content Copied!',
        'Post has been copied to clipboard',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      );

      // Prepare sharing URL based on platform
      String url;
      switch (platform) {
        case 'Twitter':
          final encodedText = Uri.encodeComponent(content);
          url = 'https://twitter.com/intent/tweet?text=$encodedText';
          break;
        case 'LinkedIn':
          final encodedText = Uri.encodeComponent(content);
          url =
              'https://www.linkedin.com/sharing/share-offsite/?text=$encodedText';
          break;
        case 'Facebook':
          final encodedText = Uri.encodeComponent(content);
          url = 'https://www.facebook.com/sharer/sharer.php?quote=$encodedText';
          break;
        default:
          throw 'Unsupported platform';
      }

      // Try to open the app first using app scheme
      bool launched = false;
      if (platform == 'Twitter') {
        launched = await launchUrl(
          Uri.parse('twitter://post?message=${Uri.encodeComponent(content)}'),
          mode: LaunchMode.externalApplication,
        );
      } else if (platform == 'LinkedIn') {
        launched = await launchUrl(
          Uri.parse('linkedin://post?message=${Uri.encodeComponent(content)}'),
          mode: LaunchMode.externalApplication,
        );
      } else if (platform == 'Facebook') {
        launched = await launchUrl(
          Uri.parse('fb://composer?message=${Uri.encodeComponent(content)}'),
          mode: LaunchMode.externalApplication,
        );
      }

      // If app scheme failed, open in browser
      if (!launched) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not share to $platform',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share to Social Media',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Twitter Option
                  _PlatformButton(
                    icon: Icons.flutter_dash,
                    platform: 'Twitter',
                    description: 'Share as Thread',
                    onTap: () => _shareOnPlatform('Twitter', twitterPost),
                  ),

                  const SizedBox(height: 16),

                  // LinkedIn Option
                  _PlatformButton(
                    icon: Icons.work,
                    platform: 'LinkedIn',
                    description: 'Share as Post',
                    onTap: () => _shareOnPlatform('LinkedIn', linkedInPost),
                  ),

                  const SizedBox(height: 16),

                  // Facebook Option
                  _PlatformButton(
                    icon: Icons.facebook,
                    platform: 'Facebook',
                    description: 'Share as Post',
                    onTap: () => _shareOnPlatform('Facebook', facebookPost),
                  ),

                  const SizedBox(height: 24),

                  // Preview section
                  ExpansionTile(
                    title: Text(
                      'Preview Posts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.textSecondaryColor.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Twitter Thread Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              twitterPost,
                              style: TextStyle(
                                color:
                                    AppTheme.textPrimaryColor.withOpacity(0.8),
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              'LinkedIn Post Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              linkedInPost,
                              style: TextStyle(
                                color:
                                    AppTheme.textPrimaryColor.withOpacity(0.8),
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              'Facebook Post Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              facebookPost,
                              style: TextStyle(
                                color:
                                    AppTheme.textPrimaryColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformButton extends StatelessWidget {
  final IconData icon;
  final String platform;
  final String description;
  final VoidCallback onTap;

  const _PlatformButton({
    required this.icon,
    required this.platform,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
