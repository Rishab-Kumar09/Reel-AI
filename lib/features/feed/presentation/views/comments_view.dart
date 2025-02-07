import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/comments_controller.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

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
              print(
                  'Rebuilding comments list. Count: ${_commentsController.comments.length}');
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
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            comment.username[0].toUpperCase(),
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
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
                                          color: AppTheme.textSecondaryColor,
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
                        print('Posting comment: $text');
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
