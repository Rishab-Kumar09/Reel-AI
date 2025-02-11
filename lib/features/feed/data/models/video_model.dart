import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String userId;
  final String username;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final String category;
  final List<String> topics;
  final List<String> skills;
  final String difficultyLevel;
  final int duration;
  final int likes;
  final int comments;
  final int shares;
  final DateTime? createdAt;
  final Map<String, dynamic>? aiMetadata; // Stores AI-generated insights
  final Map<String, List<double>>? timestamps; // Key moments in video
  final Map<String, String>? transcription; // Time-stamped transcription
  final bool? isVertical;

  const VideoModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.category,
    required this.topics,
    required this.skills,
    required this.difficultyLevel,
    required this.duration,
    required this.likes,
    required this.comments,
    required this.shares,
    this.createdAt,
    this.aiMetadata,
    this.timestamps,
    this.transcription,
    this.isVertical,
  });

  // Convert Firestore document to VideoModel
  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      topics: List<String>.from(data['topics'] ?? []),
      skills: List<String>.from(data['skills'] ?? []),
      difficultyLevel: data['difficultyLevel'] ?? 'beginner',
      duration: data['duration'] ?? 0,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      aiMetadata: data['aiMetadata'],
      timestamps: Map<String, List<double>>.from(data['timestamps'] ?? {}),
      transcription: Map<String, String>.from(data['transcription'] ?? {}),
      isVertical: data['isVertical'] ?? false,
    );
  }

  // Convert VideoModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'category': category,
      'topics': topics,
      'skills': skills,
      'difficultyLevel': difficultyLevel,
      'duration': duration,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'createdAt': createdAt,
      'aiMetadata': aiMetadata,
      'timestamps': timestamps,
      'transcription': transcription,
      'isVertical': isVertical,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'title': title,
        'description': description,
        'username': username,
        'userId': userId,
        'category': category,
        'createdAt': createdAt?.toIso8601String(),
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'isVertical': isVertical,
        'topics': topics,
        'skills': skills,
        'difficultyLevel': difficultyLevel,
        'duration': duration,
      };

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        username: json['username'] as String,
        videoUrl: json['videoUrl'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String? ?? 'general',
        createdAt: DateTime.parse(json['createdAt'] as String),
        likes: json['likes'] as int? ?? 0,
        comments: json['comments'] as int? ?? 0,
        shares: json['shares'] as int? ?? 0,
        isVertical: json['isVertical'] as bool? ?? false,
        topics: List<String>.from(json['topics'] ?? []),
        skills: List<String>.from(json['skills'] ?? []),
        difficultyLevel: json['difficultyLevel'] as String? ?? 'beginner',
        duration: json['duration'] as int? ?? 0,
      );
}
