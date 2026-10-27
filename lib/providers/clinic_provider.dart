import 'package:flutter/material.dart';
import '../models/clinic_model.dart';
import '../models/article_model.dart';
import '../services/api_service.dart';

class ClinicProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Clinic> _clinics = [];
  List<Article> _articles = [];
  bool _isLoading = false;

  List<Clinic> get clinics => [..._clinics];
  List<Article> get articles => [..._articles];
  bool get isLoading => _isLoading;

  Future<void> loadClinicsAndArticles() async {
    _isLoading = true;
    notifyListeners();

    final clinicsFuture = _apiService.fetchClinics();
    final articlesFuture = _apiService.fetchArticles();

    final results = await Future.wait([clinicsFuture, articlesFuture]);

    _clinics = results[0] as List<Clinic>;
    _articles = results[1] as List<Article>;

    _isLoading = false;
    notifyListeners();
  }
}
