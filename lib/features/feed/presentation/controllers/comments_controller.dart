import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/comment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();
  String videoId;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final RxList<CommentModel> comments = <CommentModel>[].obs;
  final RxBool isLoading = false.obs;

  CommentsController({required this.videoId});

  @override
  void onInit() {
    super.onInit();
    loadComments();
  }

  Future<void> loadComments() async {
    try {
      print('Loading comments for video: $videoId');
      isLoading.value = true;
      final querySnapshot = await _firestore
          .collection('comments')
          .where('videoId', isEqualTo: videoId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} comments');

      // Print each comment document for debugging
      querySnapshot.docs.forEach((doc) {
        print('Comment doc: ${doc.data()}');
      });

      comments.value = querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      print('Loaded ${comments.length} comments into the list');

      // Update video comment count
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({
        'comments': comments.length,
      });
    } catch (e, stackTrace) {
      print('Error loading comments: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addComment(String text) async {
    try {
      final currentUser = _authController.user.value;
      if (currentUser == null) return;

      final commentRef = _firestore.collection('comments').doc();
      final comment = CommentModel(
        id: commentRef.id,
        userId: currentUser.id,
        username: currentUser.name ?? currentUser.email,
        videoId: videoId,
        text: text,
        createdAt: DateTime.now(),
        likes: 0,
      );

      await commentRef.set(comment.toMap());

      // Update video comment count
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({
        'comments': FieldValue.increment(1),
      });

      // Refresh comments
      await loadComments();
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> likeComment(String commentId) async {
    try {
      final userId = _authController.user.value?.id;
      if (userId == null) return;

      final commentRef = _firestore.collection('comments').doc(commentId);
      final likeRef =
          _firestore.collection('comment_likes').doc('${commentId}_$userId');

      final likeDoc = await likeRef.get();

      await _firestore.runTransaction((transaction) async {
        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(commentRef, {
            'likes': FieldValue.increment(-1),
          });
        } else {
          // Like
          transaction.set(likeRef, {
            'userId': userId,
            'commentId': commentId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(commentRef, {
            'likes': FieldValue.increment(1),
          });
        }
      });

      // Refresh comments
      await loadComments();
    } catch (e) {
      print('Error liking comment: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final userId = _authController.user.value?.id;
      if (userId == null) return;

      final commentDoc =
          await _firestore.collection('comments').doc(commentId).get();
      final comment = CommentModel.fromFirestore(commentDoc);

      if (comment.userId != userId) {
        throw 'You can only delete your own comments';
      }

      await _firestore.collection('comments').doc(commentId).delete();

      // Update video comment count
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({
        'comments': FieldValue.increment(-1),
      });

      // Refresh comments
      await loadComments();
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }
}
