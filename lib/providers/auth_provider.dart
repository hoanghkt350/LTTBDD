import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/app_error.dart';
import '../services/email_verification.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({FirebaseService? service})
    : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;
  AppUser? _user;
  bool _isAdmin = false;
  String? _pendingEmail;
  bool _isCheckingSession = true;
  EmailVerificationDelivery? _verificationDelivery;
  DateTime? _resendAt;
  DateTime? _linkResendAt;
  bool _verificationServiceUnavailable = false;
  bool _isLoading = false;
  String? error;
  StreamSubscription? _subscription;
  StreamSubscription<bool>? _approvalSubscription;
  bool _approvedAdmin = false;
  String? _approvalUid;
  int _generation = 0;
  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => isAuthenticated && _isAdmin;
  bool get isLoading => _isLoading;
  String? get pendingEmail => _pendingEmail;
  bool get needsEmailVerification => _pendingEmail != null;
  bool get isCheckingSession => _isCheckingSession;
  EmailVerificationDelivery? get verificationDelivery => _verificationDelivery;
  DateTime? get resendAt => _resendAt;
  DateTime? get linkResendAt => _linkResendAt;
  bool get verificationServiceUnavailable => _verificationServiceUnavailable;
  bool get supportsGoogleSignIn => FirebaseService.supportsGoogleSignIn;

  Future<void> checkAuthStatus() async {
    if (!_service.isReady || _subscription != null) return;
    _subscription = _service.auth.userChanges().listen((user) async {
      final generation = ++_generation;
      final previousApproval = _approvalSubscription;
      _approvalSubscription = null;
      await previousApproval?.cancel();
      if (generation != _generation) return;
      if (user == null || _approvalUid != user.uid) {
        _approvedAdmin = false;
      }
      _approvalUid = user?.uid;
      if (user == null) {
        _isAdmin = false;
        _isCheckingSession = false;
        _user = null;
        _pendingEmail = null;
        _verificationDelivery = null;
        _resendAt = null;
        _linkResendAt = null;
        _verificationServiceUnavailable = false;
        notifyListeners();
        return;
      }
      _isCheckingSession = _user == null;
      var hasAdminClaim = false;
      try {
        final token = await user.getIdTokenResult();
        if (generation != _generation) return;
        hasAdminClaim = token.claims?['admin'] == true;
        _isAdmin = hasAdminClaim || _approvedAdmin;
      } catch (e) {
        if (generation != _generation) return;
        _isAdmin = false;
        _isCheckingSession = false;
        error = errorMessage(e);
        notifyListeners();
        return;
      }
      if (generation != _generation) return;
      _isCheckingSession = false;
      _pendingEmail = null;
      _user = _service.profileFromAuth(user);
      notifyListeners();
      _approvalSubscription = _service
          .watchAdminApproval(user.uid)
          .listen(
            (approved) {
              if (generation != _generation) return;
              _approvedAdmin = approved;
              _isAdmin = hasAdminClaim || approved;
              notifyListeners();
            },
            onError: (Object _) {
              if (generation != _generation) return;
              _approvedAdmin = false;
              _isAdmin = hasAdminClaim;
              notifyListeners();
            },
          );
      try {
        final profile = await _service.getProfile(user);
        if (generation != _generation) return;
        _user = profile;
        error = null;
      } catch (e) {
        if (generation != _generation) return;
        error = errorMessage(e);
        _user = _service.profileFromAuth(user);
      }
      notifyListeners();
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_isLoading) return false;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) => _run(() async {
    await _service.signInWithEmail(email.trim(), password);
  });
  Future<bool> loginWithGoogle() async {
    var signedIn = false;
    final ok = await _run(() async {
      signedIn = await _service.signInWithGoogle();
    });
    return ok && signedIn;
  }

  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        await _service.register(name, email, password);
      });
  Future<bool> sendVerificationCode() => _run(() async {
    try {
      _verificationDelivery = await _service.sendVerificationCode();
      _verificationServiceUnavailable = false;
      _resendAt = _verificationDelivery?.resendAt;
      if (_verificationDelivery == null) {
        await _service.refreshVerification();
      }
    } on FirebaseFunctionsException catch (e) {
      _verificationServiceUnavailable = [
        'not-found',
        'unimplemented',
        'unavailable',
        'internal',
        'deadline-exceeded',
      ].contains(e.code);
      // The backend supplies its deadline even for rate-limit/delivery failures.
      final details = e.details;
      if (details is Map && details['resendAt'] is num) {
        _resendAt = DateTime.fromMillisecondsSinceEpoch(
          (details['resendAt'] as num).toInt(),
        );
      }
      rethrow;
    }
  });
  Future<bool> verifyEmailCode(String code) =>
      _run(() => _service.verifyEmailCode(code));
  Future<bool> refreshVerification() =>
      _run(() => _service.refreshVerification());
  Future<bool> sendVerificationLink() => _run(() async {
    if (_linkResendAt?.isAfter(DateTime.now()) ?? false) {
      throw StateError('Vui lòng chờ một phút trước khi gửi lại liên kết.');
    }
    await _service.sendVerificationLink();
    _linkResendAt = DateTime.now().add(const Duration(seconds: 60));
  });
  Future<bool> refreshPermissions() => _run(() async {
    final user = _service.auth.currentUser;
    final allowed = await _service.hasAdminAccess(forceRefresh: true);
    if (user != null && _user?.uid == user.uid) _isAdmin = allowed;
  });
  Future<bool> resetPassword(String email) =>
      _run(() => _service.resetPassword(email));
  Future<bool> updateProfile(AppUser user) => _run(() async {
    await _service.saveProfile(user);
    _user = user;
  });
  Future<void> logout() async {
    await _service.auth.signOut();
    _generation++;
    await _approvalSubscription?.cancel();
    _approvalSubscription = null;
    _user = null;
    _isAdmin = false;
    _approvedAdmin = false;
    _approvalUid = null;
    _pendingEmail = null;
    _verificationDelivery = null;
    _resendAt = null;
    _linkResendAt = null;
    _verificationServiceUnavailable = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _approvalSubscription?.cancel();
    super.dispose();
  }
}
