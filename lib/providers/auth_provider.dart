import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/app_error.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;
  String? error;
  StreamSubscription? _subscription;
  int _generation = 0;
  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> checkAuthStatus() async {
    if (!FirebaseService.isFirebaseInitialized) return;
    _subscription = FirebaseService.instance.auth.authStateChanges().listen((
      user,
    ) async {
      final generation = ++_generation;
      if (user == null) {
        _user = null;
        notifyListeners();
        return;
      }
      _user = FirebaseService.instance.profileFromAuth(user);
      notifyListeners();
      try {
        final profile = await FirebaseService.instance.getProfile(user);
        if (generation != _generation) return;
        _user = profile;
        error = null;
      } catch (e) {
        if (generation != _generation) return;
        error = errorMessage(e);
        _user = FirebaseService.instance.profileFromAuth(user);
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
    _user = await FirebaseService.instance.signInWithEmail(email, password);
  });
  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        _user = await FirebaseService.instance.register(name, email, password);
      });
  Future<bool> resetPassword(String email) =>
      _run(() => FirebaseService.instance.resetPassword(email));
  Future<bool> updateProfile(AppUser user) => _run(() async {
    await FirebaseService.instance.saveProfile(user);
    _user = user;
  });
  Future<void> logout() async {
    await FirebaseService.instance.auth.signOut();
    _generation++;
    _user = null;
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
