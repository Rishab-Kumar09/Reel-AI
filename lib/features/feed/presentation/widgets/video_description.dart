import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoDescription extends StatelessWidget {
  final String username;
  final String? userId;
  final String description;
  final String songName;
  final String title;

  const VideoDescription({
    super.key,
    required this.username,
    this.userId,
    required this.description,
    required this.songName,
    required this.title,
  });

  Future<Map<String, dynamic>?> _getUserData() async {
    if (userId == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return {
          'name': doc.data()?['name'] as String?,
          'photoUrl': doc.data()?['photoUrl'] as String?,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title First - Larger and More Prominent
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        // User Info Section
        if (userId != null)
          FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final displayName = userData?['name'];
              final photoUrl = userData?['photoUrl'];

              return Row(
                children: [
                  // Profile Picture
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.surfaceColor,
                                child: Icon(
                                  Icons.person,
                                  color: AppTheme.textSecondaryColor,
                                  size: 20,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.surfaceColor,
                                child: Icon(
                                  Icons.person,
                                  color: AppTheme.textSecondaryColor,
                                  size: 20,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.surfaceColor,
                              child: Icon(
                                Icons.person,
                                color: AppTheme.textSecondaryColor,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // User Info
                  Expanded(
                    child: Text(
                      displayName != null && displayName != username
                          ? '$displayName\n@$username'
                          : '@$username',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              );
            },
          )
        else
          Row(
            children: [
              // Default Profile Picture
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: Container(
                    color: AppTheme.surfaceColor,
                    child: Icon(
                      Icons.person,
                      color: AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Username
              Expanded(
                child: Text(
                  '@$username',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.music_note,
              color: AppTheme.textPrimaryColor,
              size: 15,
            ),
            const SizedBox(width: 4),
            Text(
              songName,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
