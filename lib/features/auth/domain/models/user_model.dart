import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final String? bio;
  final List<String> savedVideos;
  final Map<String, dynamic> progress;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.bio,
    this.savedVideos = const [],
    this.progress = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      savedVideos: List<String>.from(data['savedVideos'] ?? []),
      progress: data['progress'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'bio': bio,
      'savedVideos': savedVideos,
      'progress': progress,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? bio,
    List<String>? savedVideos,
    Map<String, dynamic>? progress,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      savedVideos: savedVideos ?? this.savedVideos,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 