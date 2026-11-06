import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/firebase_service.dart';
import '../services/app_error.dart';

class ShopProvider with ChangeNotifier {
  List<Product> _all = [];
  String _selectedCategory = 'ALL', _searchQuery = '';
  bool _isLoading = false, _disposed = false;
  String? error;
  List<Product> get products {
    final q = _searchQuery.trim().toLowerCase();
    return _all
        .where(
          (p) =>
              (_selectedCategory == 'ALL' || p.category == _selectedCategory) &&
              (q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q)),
        )
        .toList();
  }

  List<Product> get featured => _all.where((p) => p.isFeatured).toList();
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  Future<void> fetchProducts() async {
    if (_isLoading) return;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      _all = await FirebaseService.instance.getProducts();
    } catch (e) {
      error = errorMessage(e);
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setCategory(String value) {
    _selectedCategory = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
