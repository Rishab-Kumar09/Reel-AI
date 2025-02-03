import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_firebase_app_new/features/auth/domain/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '403328203757-0ha0if5qei80us7l4m5hl5vlu3av5eta.apps.googleusercontent.com' : null,
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _createUserDocument(credential.user!);
      
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // For web, use Firebase Auth directly
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // For mobile, use GoogleSignIn
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          throw 'Sign in aborted by user';
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        await _createUserDocument(userCredential.user!);
        
        return userCredential;
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw e.message ?? 'An error occurred during Google sign in';
      }
      throw e.toString();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final userSnapshot = await userDoc.get();

    if (!userSnapshot.exists) {
      final userData = UserModel(
        id: user.uid,
        email: user.email!,
        name: user.displayName,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userDoc.set(userData.toFirestore());
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData() async {
    try {
      if (currentUser == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user data
  Future<void> updateUserData(UserModel userData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userData.id)
          .update(userData.toFirestore());
    } catch (e) {
      rethrow;
    }
  }
} 