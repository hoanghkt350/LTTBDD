import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

String errorMessage(Object error) {
  if (error is TimeoutException) {
    return 'Kết nối quá lâu. Kiểm tra mạng và thử lại.';
  }
  if (error is FirebaseFunctionsException) {
    if (error.code == 'not-found' || error.code == 'unimplemented') {
      return 'Dịch vụ gửi mã chưa được kích hoạt. Vui lòng liên hệ quản trị viên.';
    }
    if (error.code == 'internal') {
      return 'Chưa kết nối được dịch vụ xác nhận. Vui lòng thử lại sau.';
    }
    return error.message ?? 'Không xác nhận được email. Vui lòng thử lại.';
  }
  if (error is ArgumentError) return error.message.toString();
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email hoặc mật khẩu không đúng.',
      'email-already-in-use' => 'Email này đã được đăng ký.',
      'weak-password' || 'password-does-not-meet-requirements' => 'Mật khẩu cần ít nhất 10 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt.',
      'invalid-email' => 'Email không hợp lệ.',
      'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
      'too-many-requests' => 'Bạn thử quá nhiều lần. Vui lòng thử lại sau.',
      'network-request-failed' ||
      'unavailable' => 'Không kết nối được Firebase. Kiểm tra mạng và thử lại.',
      'permission-denied' =>
        'Firebase từ chối truy cập. Kiểm tra Firestore Rules.',
      'operation-not-allowed' =>
        'Chưa bật Email/Password trong Firebase Console.',
      'invalid-api-key' => 'Cấu hình Firebase chưa hợp lệ. Thay google-services.json và build lại.',
      _ => 'Firebase: ${error.message ?? error.code}',
    };
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
