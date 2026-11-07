import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/models/user_model.dart';
import 'package:pawpals_app/providers/auth_provider.dart';
import 'package:pawpals_app/services/auth_validation.dart';
import 'package:pawpals_app/services/firebase_service.dart';

class _Token extends Fake implements fb.IdTokenResult {
  _Token(this.admin);
  final Object? admin;
  @override
  Map<String, dynamic> get claims => {'email_verified': true, 'admin': admin};
}

class _User extends Fake implements fb.User {
  _User(this.uid, {this.emailVerified = false, this.admin = false});
  final Object? admin;
  @override
  final String uid;
  @override
  final bool emailVerified;
  @override
  String get email => '$uid@gmail.com';
  @override
  Future<fb.IdTokenResult> getIdTokenResult([
    bool forceRefresh = false,
  ]) async => _Token(admin);
}

class _Auth extends Fake implements fb.FirebaseAuth {
  final changes = StreamController<fb.User?>.broadcast();
  @override
  Stream<fb.User?> userChanges() => changes.stream;
  @override
  Future<void> signOut() async => changes.add(null);
}

class _Service extends Fake implements FirebaseService {
  @override
  final _Auth auth = _Auth();
  int reads = 0;
  Completer<AppUser>? profile;
  @override
  bool get isReady => true;
  @override
  AppUser profileFromAuth(fb.User user) =>
      AppUser(uid: user.uid, email: user.email!, displayName: user.uid);
  @override
  Future<AppUser> getProfile(fb.User user) async {
    reads++;
    return profile?.future ?? profileFromAuth(user);
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('only a verified boolean admin token grants management access and logout clears it', () async {
    final service = _Service();
    final auth = AuthProvider(service: service);
    await auth.checkAuthStatus();
    for (final claim in [null, false, 'true', 1]) {
      service.auth.changes.add(
        _User('alice', emailVerified: true, admin: claim),
      );
      await _flush();
      expect(auth.isAdmin, isFalse);
    }
    service.auth.changes.add(_User('alice', admin: true));
    await _flush();
    expect(auth.isAdmin, isFalse);
    service.auth.changes.add(_User('alice', emailVerified: true, admin: true));
    await _flush();
    expect(auth.isAdmin, isTrue);
    service.auth.changes.add(_User('alice', emailVerified: true));
    await _flush();
    expect(auth.isAdmin, isFalse);
    service.auth.changes.add(_User('alice', emailVerified: true, admin: true));
    await _flush();
    await auth.logout();
    await _flush();
    expect(auth.isAdmin, isFalse);
    auth.dispose();
    await service.auth.changes.close();
  });
  test('registration requires a strong password', () {
    for (final password in [
      '',
      'short',
      'alllowercase1!',
      'ALLUPPERCASE1!',
      'NoNumbersHere!',
      'NoSymbols12345',
    ]) {
      expect(registrationPasswordError(password), isNotNull);
    }
    expect(registrationPasswordError('PawPals2026!'), isNull);
    expect(registrationPasswordError('A1!${'a' * 126}'), isNotNull);
  });

  test(
    'unverified sessions never load private profiles or become authenticated',
    () async {
      final service = _Service();
      final auth = AuthProvider(service: service);
      await auth.checkAuthStatus();
      service.auth.changes.add(_User('alice'));
      await _flush();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.pendingEmail, 'alice@gmail.com');
      expect(service.reads, 0);
      service.auth.changes.add(_User('alice', emailVerified: true));
      await _flush();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.pendingEmail, isNull);
      expect(service.reads, 1);
      await auth.logout();
      await _flush();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.needsEmailVerification, isFalse);
      auth.dispose();
      await service.auth.changes.close();
    },
  );

  test('a delayed profile cannot restore a session after logout', () async {
    final service = _Service()..profile = Completer<AppUser>();
    final auth = AuthProvider(service: service);
    await auth.checkAuthStatus();
    service.auth.changes.add(_User('alice', emailVerified: true));
    await _flush();
    await auth.logout();
    await _flush();
    service.profile!.complete(
      AppUser(uid: 'alice', email: 'alice@gmail.com', displayName: 'Alice'),
    );
    await _flush();
    expect(auth.user, isNull);
    auth.dispose();
    await service.auth.changes.close();
  });
}
