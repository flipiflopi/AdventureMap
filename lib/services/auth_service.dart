// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Iniciar sesión con email y contraseña
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      print('❌ Error en signIn: ${e.code}');
      // Lanzamos el código técnico para que la UI lo traduzca con AppLocalizations
      throw Exception(e.code);
    }
  }

  /// Registrarse con email y contraseña
  Future<UserCredential> registerWithEmailPassword(
      String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Crear perfil de usuario en Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'displayName': email.split('@')[0],
        'photoUrl': null,
        'favoriteSpots': [],
        'adventureScore': 0,
        'isModerator': false,
        'friends': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (e) {
      print('❌ Error en register: ${e.code}');
      // Lanzamos el código técnico
      throw Exception(e.code);
    }
  }

  /// Obtener usuario actual
  User? get user => _auth.currentUser;

  /// Iniciar sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // El usuario canceló el login
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Verificar si es un nuevo usuario y crear perfil en Firestore
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          // 'displayName' usa un valor por defecto si no viene de Google
          'displayName': userCredential.user!.displayName ?? 'Explorer',
          'photoUrl': userCredential.user!.photoURL,
          'favoriteSpots': [],
          'adventureScore': 0,
          'isModerator': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Restablecer contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  /// Eliminar cuenta
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Eliminar datos del usuario en Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      // Eliminar cuenta de Firebase Auth
      await user.delete();
    }
  }
}