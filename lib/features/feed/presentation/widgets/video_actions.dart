import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class VideoActions extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMuteToggle;
  final String likes;
  final String comments;
  final String shares;
  final bool isMuted;

  const VideoActions({
    super.key,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMuteToggle,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          label: isMuted ? 'Unmute' : 'Mute',
          onTap: onMuteToggle,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.favorite,
          label: likes,
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.comment,
          label: comments,
          onTap: onComment,
        ),
        const SizedBox(height: 20),
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
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(
              icon,
              color: AppTheme.textPrimaryColor,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 4),
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
