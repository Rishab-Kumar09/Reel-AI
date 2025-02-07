import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String userId;
  final String username;
  final String videoId;
  final String text;
  final DateTime createdAt;
  final int likes;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.videoId,
    required this.text,
    required this.createdAt,
    required this.likes,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      videoId: data['videoId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'videoId': videoId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
    };
  }
}
