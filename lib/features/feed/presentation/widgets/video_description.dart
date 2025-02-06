import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class VideoDescription extends StatelessWidget {
  final String username;
  final String description;
  final String songName;
  final String title;

  const VideoDescription({
    super.key,
    required this.username,
    required this.description,
    required this.songName,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          title,
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Username
        Text(
          username,
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Description
        Text(
          description,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textPrimaryColor,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Song name
        Row(
          children: [
            Icon(
              Icons.music_note,
              color: AppTheme.textPrimaryColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                songName,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
