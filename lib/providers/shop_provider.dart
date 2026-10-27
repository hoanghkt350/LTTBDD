import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/firebase_mock_service.dart';

class ShopProvider with ChangeNotifier {
  List<Product> _products = [];
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  bool _isLoading = false;

  List<Product> get products => [..._products];
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    _products = await FirebaseService.instance.getProducts(
      category: _selectedCategory,
      query: _searchQuery,
    );

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      fetchProducts();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchProducts();
  }
}
