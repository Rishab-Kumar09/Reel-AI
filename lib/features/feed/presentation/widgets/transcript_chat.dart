import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/chat_service.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/transcription_service.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/social_share_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class TranscriptChat extends StatefulWidget {
  final String transcript;
  final String videoId;

  const TranscriptChat({
    Key? key,
    required this.transcript,
    required this.videoId,
  }) : super(key: key);

  @override
  State<TranscriptChat> createState() => _TranscriptChatState();
}

class _TranscriptChatState extends State<TranscriptChat> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RxList<ChatMessage> _messages = <ChatMessage>[].obs;
  final RxBool _isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    // Add initial transcript message
    _messages.add(ChatMessage(
      text: widget.transcript,
      isUser: false,
      type: MessageType.transcript,
    ));
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      // Add user question
      _messages.add(ChatMessage(
        text: question,
        isUser: true,
        type: MessageType.question,
      ));
      _questionController.clear();
    });

    // Scroll to bottom
    await _scrollToBottom();

    try {
      _isLoading.value = true;

      // Get answer from GPT using only the transcript context
      final answer = await _getAnswerFromTranscript(question);

      _messages.add(ChatMessage(
        text: answer,
        isUser: false,
        type: MessageType.answer,
      ));

      await _scrollToBottom();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get answer: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<String> _getAnswerFromTranscript(String question) async {
    try {
      final chatService = ChatService();
      return await chatService.getAnswerFromTranscript(
          widget.transcript, question);
    } catch (e) {
      return 'Sorry, I encountered an error while trying to answer your question. Please try again.';
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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

          // Share button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _showSocialShareSheet(context),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: Obx(() => ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                )),
          ),

          // Input field
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask about the video...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleQuestion,
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => IconButton(
                      onPressed: _isLoading.value
                          ? null
                          : () => _handleQuestion(_questionController.text),
                      icon: _isLoading.value
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      color: AppTheme.primaryColor,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isTranscript = message.type == MessageType.transcript;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isTranscript) ...[
            Text(
              message.isUser ? 'You' : 'AI Assistant',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isTranscript
                  ? AppTheme.surfaceColor
                  : message.isUser
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: isTranscript
                  ? Border.all(
                      color: AppTheme.textSecondaryColor.withOpacity(0.2),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isTranscript)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transcript',
                          style: AppTheme.titleSmall.copyWith(
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () =>
                              _copyToClipboard(message.text, 'Transcript'),
                          color: AppTheme.primaryColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy transcript',
                        ),
                      ],
                    ),
                  ),
                if (!isTranscript)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          message.text,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                      if (!message.isUser) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () =>
                              _copyToClipboard(message.text, 'Answer'),
                          color: AppTheme.primaryColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy answer',
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    message.text,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text, String type) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      Get.snackbar(
        'Copied!',
        '$type copied to clipboard',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.1),
        colorText: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to copy $type',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
      );
    }
  }

  Future<void> _showSocialShareSheet(BuildContext context) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final transcriptionService = TranscriptionService();
      final posts = await transcriptionService.generateSocialPosts(
        widget.videoId,
        existingTranscript: widget.transcript,
      );

      Get.back(); // Close loading dialog

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => SocialShareSheet(
            twitterPost: posts['twitter']!,
            linkedInPost: posts['linkedin']!,
            facebookPost: posts['facebook']!,
          ),
        ),
      );
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to generate social posts: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
      );
    }
  }
}

enum MessageType {
  transcript,
  question,
  answer,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final MessageType type;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.type,
  });
}
