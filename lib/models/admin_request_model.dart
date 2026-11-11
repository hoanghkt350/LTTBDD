import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRequest {
  const AdminRequest({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.reason,
    required this.status,
    this.updatedAt,
    this.reviewNote = '',
  });

  final String uid, email, displayName, reason, status, reviewNote;
  final DateTime? updatedAt;

  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const revoked = 'revoked';

  static String statusLabel(String status) => switch (status) {
    pending => 'Chờ duyệt',
    approved => 'Đã được cấp quyền',
    rejected => 'Đã từ chối',
    revoked => 'Đã thu hồi quyền',
    _ => 'Chưa gửi yêu cầu',
  };

  bool get canSubmit => status == rejected || status == revoked;

  factory AdminRequest.fromMap(Map<String, dynamic> data) => AdminRequest(
    uid: (data['uid'] ?? data['_id']) as String,
    email: data['email'] as String? ?? '',
    displayName: data['displayName'] as String? ?? '',
    reason: data['reason'] as String? ?? '',
    status: data['status'] as String? ?? pending,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    reviewNote: data['reviewNote'] as String? ?? '',
  );
}
