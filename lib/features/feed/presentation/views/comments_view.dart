import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/comments_controller.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommentsView extends StatefulWidget {
  final String videoId;

  const CommentsView({
    super.key,
    required this.videoId,
  });

  @override
  State<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<CommentsView> {
  late final CommentsController _commentsController;
  final TextEditingController _commentController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> _getUserProfilePic(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['photoUrl'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user profile pic: $e');
      return null;
    }
  }

  Widget _buildProfilePicture(String userId, String username) {
    return FutureBuilder<String?>(
      future: _getUserProfilePic(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: snapshot.data!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildDefaultAvatar(username),
                errorWidget: (context, url, error) =>
                    _buildDefaultAvatar(username),
              ),
            ),
          );
        }
        return _buildDefaultAvatar(username);
      },
    );
  }

  Widget _buildDefaultAvatar(String username) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
      child: Text(
        username[0].toUpperCase(),
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('CommentsView initialized with videoId: ${widget.videoId}');
    _commentsController = Get.put(
      CommentsController(videoId: widget.videoId),
      tag: widget.videoId,
    );
    _commentsController.loadComments();
  }

  @override
  void dispose() {
    Get.delete<CommentsController>(tag: widget.videoId);
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                  color: AppTheme.textPrimaryColor,
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.surfaceColor),
          // Comments List
          Expanded(
            child: Obx(() {
              if (_commentsController.isLoading.value &&
                  _commentsController.comments.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!_commentsController.isLoading.value &&
                  _commentsController.comments.isEmpty) {
                return Center(
                  child: Text(
                    'No comments yet',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _commentsController.comments.length,
                itemBuilder: (context, index) {
                  final comment = _commentsController.comments[index];
                  final isCurrentUser =
                      comment.userId == _authController.user.value?.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfilePicture(comment.userId, comment.username),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    comment.username,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeago.format(comment.createdAt),
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.text,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _commentsController
                                        .likeComment(comment.id),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.favorite_border,
                                          size: 16,
                                          color: comment.likes > 0
                                              ? Colors.red
                                              : AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${comment.likes}',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _commentsController
                                          .deleteComment(comment.id),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(
                  color: AppTheme.textSecondaryColor.withOpacity(0.1),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final text = _commentController.text.trim();
                      if (text.isNotEmpty) {
                        _commentsController.addComment(text);
                        _commentController.clear();
                      }
                    },
                    child: Text(
                      'Post',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
