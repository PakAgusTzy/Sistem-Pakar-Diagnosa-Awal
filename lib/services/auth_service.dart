import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // 🔹 Jalankan langsung provider Google via popup untuk Web
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await _saveUser(cred.user!);
      return cred;
    } else {
      // 🔹 Android/iOS pakai package google_sign_in
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) throw Exception('Login dibatalkan pengguna.');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _saveUser(cred.user!);
      return cred;
    }
  }

  Future<void> _saveUser(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    await ref.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoURL': user.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    if (!kIsWeb) { try { await GoogleSignIn().signOut(); } catch (_) {} }
    await _auth.signOut();
  }
}

final authService = AuthService();
