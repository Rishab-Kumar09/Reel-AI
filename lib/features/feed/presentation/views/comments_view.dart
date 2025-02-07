import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/comments_controller.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsView extends StatefulWidget {
  const CommentsView({super.key});

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
    final videoId = Get.arguments as String;
    _commentsController = Get.put(CommentsController(videoId: videoId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
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
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: _commentsController.comments.length,
                itemBuilder: (context, index) {
                  final comment = _commentsController.comments[index];
                  final isCurrentUser =
                      comment.userId == _authController.user.value?.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        comment.username[0].toUpperCase(),
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          comment.username,
                          style: AppTheme.titleSmall.copyWith(
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
                    subtitle: Text(
                      comment.text,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _commentsController.likeComment(comment.id),
                          icon: const Icon(Icons.favorite_border),
                          color: AppTheme.textPrimaryColor,
                        ),
                        Text(
                          comment.likes.toString(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          IconButton(
                            onPressed: () =>
                                _commentsController.deleteComment(comment.id),
                            icon: const Icon(Icons.delete_outline),
                            color: AppTheme.errorColor,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final text = _commentController.text.trim();
                    if (text.isNotEmpty) {
                      _commentsController.addComment(text);
                      _commentController.clear();
                    }
                  },
                  icon: const Icon(Icons.send),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
