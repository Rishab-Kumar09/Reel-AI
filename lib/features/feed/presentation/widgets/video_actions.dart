import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class VideoActions extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final String likes;
  final String comments;
  final String shares;

  const VideoActions({
    super.key,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.favorite,
          label: likes,
          onTap: onLike,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.comment,
          label: comments,
          onTap: onComment,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.share,
          label: shares,
          onTap: onShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: AppTheme.textPrimaryColor,
            size: 32,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }
} 