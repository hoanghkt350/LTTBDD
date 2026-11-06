import 'package:flutter/material.dart';

import '../models/clinic_model.dart';
import '../models/article_model.dart';
import '../services/api_service.dart';
import '../services/app_error.dart';

class ClinicProvider with ChangeNotifier {
  List<Clinic> _clinics = [];
  List<Article> _articles = [];
  bool _isLoading = false, _disposed = false;
  String? error;
  List<Clinic> get clinics => List.unmodifiable(_clinics);
  List<Article> get articles => List.unmodifiable(_articles);
  bool get isLoading => _isLoading;
  Future<void> loadClinicsAndArticles() async {
    if (_isLoading) return;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService().fetchClinics(),
        ApiService().fetchArticles(),
      ]);
      _clinics = results[0] as List<Clinic>;
      _articles = results[1] as List<Article>;
    } catch (e) {
      error = errorMessage(e);
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
