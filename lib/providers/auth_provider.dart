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
  String? _pendingEmail;
  bool _isCheckingSession = true;
  EmailVerificationDelivery? _verificationDelivery;
  DateTime? _resendAt;
  bool _isLoading = false;
  String? error;
  StreamSubscription? _subscription;
  int _generation = 0;
  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get pendingEmail => _pendingEmail;
  bool get needsEmailVerification => _pendingEmail != null;
  bool get isCheckingSession => _isCheckingSession;
  EmailVerificationDelivery? get verificationDelivery => _verificationDelivery;
  DateTime? get resendAt => _resendAt;

  Future<void> checkAuthStatus() async {
    if (!_service.isReady || _subscription != null) return;
    _subscription = _service.auth.userChanges().listen((user) async {
      final generation = ++_generation;
      if (user == null || !user.emailVerified) {
        _isCheckingSession = false;
        _user = null;
        _pendingEmail = user?.email;
        if (user == null) {
          _verificationDelivery = null;
          _resendAt = null;
        }
        notifyListeners();
        return;
      }
      _isCheckingSession = _user == null;
      // Ensure rules see email_verified before creating any session providers.
      try {
        final token = await user.getIdTokenResult();
        if (token.claims?['email_verified'] != true) {
          await user.getIdToken(true);
        }
      } catch (e) {
        if (generation != _generation) return;
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
  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        await _service.register(name, email, password);
      });
  Future<bool> sendVerificationCode() => _run(() async {
    try {
      _verificationDelivery = await _service.sendVerificationCode();
      _resendAt = _verificationDelivery?.resendAt;
      if (_verificationDelivery == null) {
        await _service.refreshVerification();
      }
    } on FirebaseFunctionsException catch (e) {
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
  Future<bool> resetPassword(String email) =>
      _run(() => _service.resetPassword(email));
  Future<bool> updateProfile(AppUser user) => _run(() async {
    await _service.saveProfile(user);
    _user = user;
  });
  Future<void> logout() async {
    await _service.auth.signOut();
    _generation++;
    _user = null;
    _pendingEmail = null;
    _verificationDelivery = null;
    _resendAt = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }
}
