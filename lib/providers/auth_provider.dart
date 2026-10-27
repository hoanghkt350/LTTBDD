import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/shared_prefs_service.dart';
import '../services/firebase_mock_service.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final cachedUser = await SharedPrefsService.getCachedUser();
    if (cachedUser != null) {
      _user = cachedUser;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await FirebaseService.instance.signInWithEmail(email, password);
      _user = user;
      await SharedPrefsService.saveLoginSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    await SharedPrefsService.clearSession();
    notifyListeners();
  }
}
