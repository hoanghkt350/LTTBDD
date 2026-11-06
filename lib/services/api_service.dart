import '../models/clinic_model.dart';
import '../models/article_model.dart';
import 'firebase_service.dart';

/// Content is maintained by the project owner in Firestore.
/// No fabricated clinic distances or payment-success fallback.
class ApiService {
  Future<List<Clinic>> fetchClinics() async {
    final snapshot = await FirebaseService.instance.firestore
        .collection('clinics')
        .get()
        .timeout(const Duration(seconds: 12));
    return snapshot.docs
        .map((d) => Clinic.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<List<Article>> fetchArticles({String? category}) async {
    final snapshot = await FirebaseService.instance.firestore
        .collection('articles')
        .get()
        .timeout(const Duration(seconds: 12));
    final list = snapshot.docs
        .map((d) => Article.fromJson({...d.data(), 'id': d.id}))
        .toList();
    return category == null
        ? list
        : list.where((a) => a.category == category).toList();
  }
}
