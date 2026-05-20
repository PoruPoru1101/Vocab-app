import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    await _auth.signInWithPopup(provider);
  }

  /// ゲスト (匿名) としてサインイン。データはこのブラウザでのみアクセス可能。
  Future<void> signInAsGuest() async {
    await _auth.signInAnonymously();
  }

  /// 匿名アカウントを Google アカウントに連携。UID は維持されるので既存データはそのまま。
  Future<void> linkAnonymousToGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return;
    final provider = GoogleAuthProvider();
    await user.linkWithPopup(provider);
  }

  Future<void> signOut() => _auth.signOut();
}
