import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/feed_view.dart';
import 'package:flutter_firebase_app_new/features/discover/presentation/views/discover_view.dart';
import 'package:flutter_firebase_app_new/features/create/presentation/views/create_view.dart';
import 'package:flutter_firebase_app_new/features/profile/presentation/views/profile_view.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';
import 'package:flutter_firebase_app_new/features/create/presentation/widgets/video_metadata_form.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _currentIndex = 0;
  final SampleDataService _sampleDataService = SampleDataService();

  final List<Widget> _screens = [
    const FeedView(),
    const DiscoverView(),
    const CreateView(),
    const ProfileView(),
  ];

  @override
  void dispose() {
    _sampleDataService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // If create button is tapped (index 2)
          if (index == 2) {
            // Show create options modal
            _showCreateOptions();
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondaryColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showCreateOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(
                'Upload Video',
                style: AppTheme.bodyLarge,
              ),
              onTap: () async {
                Get.back();
                _showVideoMetadataForm(isUpload: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoMetadataForm({bool isUpload = true}) {
    bool isLoading = false;
    double uploadProgress = 0.0;

    Get.dialog(
      Dialog(
        child: StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                VideoMetadataForm(
                  isLoading: isLoading,
                  onSubmit: (metadata) async {
                    setState(() {
                      isLoading = true;
                      uploadProgress = 0.0;
                    });

                    try {
                      if (isUpload) {
                        await _sampleDataService.uploadVideoFromDevice(
                          metadata: metadata,
                          onProgress: (progress) {
                            setState(() {
                              uploadProgress = progress;
                            });
                          },
                        );
                      }
                      Get.back(); // Close the dialog
                      Get.snackbar(
                        'Success',
                        'Video uploaded successfully',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        colorText: Colors.green,
                      );
                    } catch (e) {
                      print('Error uploading video: $e');
                      Get.snackbar(
                        'Error',
                        e.toString(),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red.withOpacity(0.1),
                        colorText: Colors.red,
                      );
                    } finally {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  },
                ),
                if (isLoading && uploadProgress > 0)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: uploadProgress,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Uploading video... ${(uploadProgress * 100).toInt()}%',
                            style: AppTheme.bodyLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
