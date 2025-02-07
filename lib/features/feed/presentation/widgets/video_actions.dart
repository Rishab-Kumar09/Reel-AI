import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class VideoActions extends StatefulWidget {
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMuteToggle;
  final String likes;
  final String comments;
  final String shares;
  final bool isMuted;
  final bool isLiked;

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
    required this.isLiked,
  });

  @override
  State<VideoActions> createState() => _VideoActionsState();
}

class _VideoActionsState extends State<VideoActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    if (!widget.isLiked) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: widget.isMuted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          label: widget.isMuted ? 'Unmute' : 'Mute',
          onTap: widget.onMuteToggle,
        ),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _scaleAnimation,
          child: _buildActionButton(
            icon: Icons.favorite,
            label: widget.likes,
            onTap: _handleLike,
            color: widget.isLiked ? Colors.red : AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.comment,
          label: widget.comments,
          onTap: widget.onComment,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.share,
          label: widget.shares,
          onTap: widget.onShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
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
              color: color ?? AppTheme.textPrimaryColor,
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
