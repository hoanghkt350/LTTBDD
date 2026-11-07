import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';
import 'order_workflow.dart';

/// UI guards improve navigation; Firebase Rules enforce every permission.
class AdminService {
  AdminService({FirebaseService? firebase})
    : _firebase = firebase ?? FirebaseService.instance;
  final FirebaseService _firebase;
  static const collections = [
    'products',
    'orders',
    'clinics',
    'articles',
    'users',
  ];

  Stream<List<Map<String, dynamic>>> watch(
    String collection, {
    int limit = 100,
  }) async* {
    if (!collections.contains(collection)) {
      throw ArgumentError('Danh mục không hợp lệ.');
    }
    if (limit < 1 || limit > 5000) {
      throw ArgumentError('Giới hạn danh sách không hợp lệ.');
    }
    await _firebase.requireAdmin();
    yield* _firebase.firestore
        .collection(collection)
        .orderBy(
          collection == 'orders' ? 'createdAt' : FieldPath.documentId,
          descending: collection == 'orders',
        )
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        // Show current server results after an account/role change, rather than
        // an incomplete initial result from a previous session's local cache.
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {...doc.data(), '_id': doc.id})
              .toList(),
        );
  }

  Future<void> save(
    String collection,
    String? id,
    Map<String, dynamic> data, {
    Map<String, dynamic>? original,
  }) async {
    if (!['products', 'clinics', 'articles'].contains(collection)) {
      throw ArgumentError('Danh mục không cho phép chỉnh sửa.');
    }
    await _firebase.requireAdmin();
    final ref = id == null
        ? _firebase.firestore.collection(collection).doc()
        : _firebase.firestore.collection(collection).doc(id);
    if (collection == 'products' && id != null && original != null) {
      final conflict = await _firebase.firestore.runTransaction<String?>((
        tx,
      ) async {
        final current = await tx.get(ref);
        if (!current.exists) return 'Sản phẩm không còn tồn tại.';
        final changed = Map<String, dynamic>.fromEntries(
          data.entries.where((entry) => entry.value != original[entry.key]),
        );
        if (changed.containsKey('stock') &&
            current.data()!['stock'] != original['stock']) {
          return 'Tồn kho đã thay đổi trong lúc chỉnh sửa. Hãy tải lại sản phẩm trước khi cập nhật số lượng.';
        }
        tx.update(ref, {...changed, 'updatedAt': FieldValue.serverTimestamp()});
        return null;
      });
      if (conflict != null) throw StateError(conflict);
      return;
    }
    await ref.set({
      ...data,
      'id': ref.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteContent(String collection, String id) async {
    if (!['clinics', 'articles'].contains(collection)) {
      throw ArgumentError('Không thể xóa danh mục này.');
    }
    await _firebase.requireAdmin();
    await _firebase.firestore.collection(collection).doc(id).delete();
  }

  Future<void> setProductActive(String id, bool active) async {
    await _firebase.requireAdmin();
    await _firebase.firestore.collection('products').doc(id).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _firebase.requireAdmin();
    if (status == OrderWorkflow.cancelled) {
      return _firebase.cancelOrder(id, asAdmin: true);
    }
    final ref = _firebase.firestore.collection('orders').doc(id);
    final conflict = await _firebase.firestore.runTransaction<String?>((
      tx,
    ) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) return 'Không tìm thấy đơn hàng.';
      final previous = snapshot.data()!['status'] as String;
      if (previous == status) return null;
      if (!OrderWorkflow.nextStatuses(previous).contains(status)) {
        return 'Không thể chuyển trạng thái đơn hàng này.';
      }
      tx.update(ref, {
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': _firebase.uid,
      });
      return null;
    });
    if (conflict != null) throw StateError(conflict);
  }
}
