import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_request_model.dart';
import 'firebase_service.dart';

class AdminRequestService {
  AdminRequestService({FirebaseService? firebase})
    : _firebase = firebase ?? FirebaseService.instance;

  final FirebaseService _firebase;

  Stream<AdminRequest?> watchMine() => _firebase.firestore
      .collection('admin_requests')
      .doc(_firebase.uid)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.isFromCache)
      .map(
        (snapshot) =>
            snapshot.exists ? AdminRequest.fromMap(snapshot.data()!) : null,
      );

  Future<void> submit(String reason) async {
    final text = reason.trim();
    if (text.length < 10 || text.length > 500) {
      throw ArgumentError('Lý do cần từ 10 đến 500 ký tự.');
    }
    final uid = _firebase.uid;
    if (await _firebase.hasAdminAccess(forceRefresh: true)) {
      throw StateError('Tài khoản đã có quyền quản trị.');
    }
    final user = _firebase.auth.currentUser!;
    final ref = _firebase.firestore.collection('admin_requests').doc(uid);
    await _firebase.firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final previous = snapshot.data();
      if (previous != null &&
          ![
            AdminRequest.rejected,
            AdminRequest.revoked,
          ].contains(previous['status'])) {
        throw StateError(
          'Yêu cầu đang chờ duyệt hoặc tài khoản đã được cấp quyền.',
        );
      }
      tx.set(ref, {
        'uid': uid,
        'email': user.email!,
        'displayName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email!.split('@').first,
        'reason': text,
        'status': AdminRequest.pending,
        'createdAt': previous?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'reviewNote': '',
      });
    });
  }

  Future<void> review(String uid, String decision, {String note = ''}) async {
    if (![
      AdminRequest.approved,
      AdminRequest.rejected,
      AdminRequest.revoked,
    ].contains(decision)) {
      throw ArgumentError('Quyết định không hợp lệ.');
    }
    if (note.trim().length > 500) {
      throw ArgumentError('Phản hồi tối đa 500 ký tự.');
    }
    await _firebase.requireAdmin();
    final reviewer = _firebase.uid;
    if (reviewer == uid) {
      throw StateError('Bạn không thể tự duyệt yêu cầu của mình.');
    }
    final ref = _firebase.firestore.collection('admin_requests').doc(uid);
    await _firebase.firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final status = snapshot.data()?['status'];
      final valid = decision == AdminRequest.revoked
          ? status == AdminRequest.approved
          : status == AdminRequest.pending;
      if (!valid) {
        throw StateError('Yêu cầu đã thay đổi. Vui lòng tải lại danh sách.');
      }
      tx.update(ref, {
        'status': decision,
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer,
        'reviewNote': note.trim(),
      });
    });
  }
}
