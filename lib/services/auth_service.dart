import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Aggressively clear ALL cached data
  Future<void> _nukeCaches() async {
    print('🧹 NUKING ALL CACHES...');
    
    try {
      // Clear ALL SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ SharedPreferences cleared');
    } catch (e) {
      print('⚠️ Error clearing SharedPreferences: $e');
    }

    // Small delay to ensure caches are cleared
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailPassword(String email, String password) async {
    print('\n' + '='*50);
    print('🔐 STARTING LOGIN PROCESS');
    print('='*50);
    print('📧 Email: $email');
    
    try {
      // STEP 1: Nuke all caches
      await _nukeCaches();
      
      // STEP 2: Sign out any existing session
      print('🚪 Signing out any existing session...');
      try {
        await _auth.signOut();
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        print('⚠️ Logout error (ignored): $e');
      }

      // STEP 3: Clear caches again
      await _nukeCaches();
      
      // STEP 4: Sign in
      print('🔑 Signing in to Firebase Auth...');
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = result.user;
      if (user == null) {
        throw 'No user returned from authentication';
      }

      print('✅ FIREBASE AUTH SUCCESS!');
      print('👤 User ID: ${user.uid}');
      print('📧 Email: ${user.email}');

      // STEP 5: Get user data from Firestore
      print('📊 Fetching user profile from Firestore...');
      UserModel? userModel;
      
      try {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          userModel = UserModel.fromMap(data);
          print('✅ User profile loaded from Firestore');
        } else {
          print('⚠️ No Firestore profile - creating fallback');
          userModel = _createFallbackUser(user, email);
        }
      } catch (firestoreError) {
        print('⚠️ Firestore error: $firestoreError');
        userModel = _createFallbackUser(user, email);
      }

      print('='*50);
      print('✅ LOGIN COMPLETE!');
      print('='*50 + '\n');
      
      return userModel;
      
    } on FirebaseAuthException catch (e) {
      print('❌ FIREBASE AUTH ERROR: ${e.code}');
      print('📝 Message: ${e.message}');
      await _nukeCaches(); // Clear caches on error
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ UNEXPECTED ERROR: $e');
      await _nukeCaches(); // Clear caches on error
      throw 'Login failed: ${e.toString()}';
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    print('\n' + '='*50);
    print('📝 STARTING REGISTRATION PROCESS');
    print('='*50);
    print('📧 Email: $email');
    print('👤 Name: $displayName');
    
    try {
      // STEP 1: Nuke all caches
      await _nukeCaches();
      
      // STEP 2: Sign out any existing session
      print('🚪 Signing out any existing session...');
      try {
        await _auth.signOut();
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        print('⚠️ Logout error (ignored): $e');
      }

      // STEP 3: Clear caches again
      await _nukeCaches();
      
      // STEP 4: Create account
      print('🔑 Creating Firebase Auth account...');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = result.user;
      if (user == null) {
        throw 'No user returned from registration';
      }

      print('✅ FIREBASE AUTH ACCOUNT CREATED!');
      print('👤 User ID: ${user.uid}');

      // STEP 5: Create user model
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        createdAt: DateTime.now(),
      );

      // STEP 6: Save to Firestore
      print('💾 Saving profile to Firestore...');
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        
        print('✅ Profile saved to Firestore');
      } catch (firestoreError) {
        print('⚠️ Firestore save failed: $firestoreError');
        print('✅ But auth succeeded - continuing...');
      }

      print('='*50);
      print('✅ REGISTRATION COMPLETE!');
      print('='*50 + '\n');
      
      return userModel;
      
    } on FirebaseAuthException catch (e) {
      print('❌ FIREBASE AUTH ERROR: ${e.code}');
      print('📝 Message: ${e.message}');
      await _nukeCaches(); // Clear caches on error
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ UNEXPECTED ERROR: $e');
      await _nukeCaches(); // Clear caches on error
      throw 'Registration failed: ${e.toString()}';
    }
  }

  // Create fallback user when Firestore fails
  UserModel _createFallbackUser(User user, String email) {
    return UserModel(
      uid: user.uid,
      email: email,
      displayName: email.split('@')[0],
      createdAt: DateTime.now(),
    );
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
          
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    print('\n🚪 SIGNING OUT...');
    
    try {
      // Clear caches before signing out
      await _nukeCaches();
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Clear caches again after signing out
      await _nukeCaches();
      
      print('✅ Signed out successfully\n');
    } catch (e) {
      print('❌ Error signing out: $e');
      await _nukeCaches(); // Force clear even on error
      throw 'Sign out failed: ${e.toString()}';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'network-request-failed':
        return 'Network error. Check your internet connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'invalid-credential':
        return 'Invalid login credentials';
      default:
        return e.message ?? 'Authentication error occurred';
    }
  }
}