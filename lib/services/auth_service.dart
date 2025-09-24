import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logging_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password, String fullName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'idVerified': 'not_submitted', // not_submitted, pending, approved, rejected
        'role': 'user', // user, admin
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await result.user!.updateDisplayName(fullName);
      notifyListeners();
      return result;
    } catch (e) {
      LoggingService.error('Sign up error: $e', error: e);
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return result;
    } catch (e) {
      LoggingService.error('Sign in error: $e', error: e);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      LoggingService.error('Sign out error: $e', error: e);
      rethrow;
    }
  }

  // Get user verification status
  Future<String> getUserVerificationStatus() async {
    if (currentUser == null) return 'not_submitted';
    
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['idVerified'] ?? 'not_submitted';
      }
      return 'not_submitted';
    } catch (e) {
      LoggingService.error('Error getting verification status: $e', error: e);
      return 'not_submitted';
    }
  }

  // Update user verification status (for admin use)
  Future<void> updateVerificationStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'idVerified': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to audit log
      await _firestore.collection('verification_audit').add({
        'userId': userId,
        'adminId': currentUser?.uid,
        'action': 'status_update',
        'newStatus': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggingService.error('Error updating verification status: $e', error: e);
      rethrow;
    }
  }
}