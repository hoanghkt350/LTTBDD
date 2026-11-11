import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

String errorMessage(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError => 'Chưa cấu hình đăng nhập Google cho bản ứng dụng này. Vui lòng liên hệ quản trị viên.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Chưa mở được đăng nhập Google. Vui lòng thử lại.',
      _ => 'Không đăng nhập được Google. Kiểm tra kết nối mạng và thử lại.',
    };
  }
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
      'permission-denied' => 'Bạn không có quyền thực hiện thao tác này. Hãy cập nhật quyền tài khoản hoặc đăng nhập lại.',
      'operation-not-allowed' =>
        'Phương thức đăng nhập này chưa được bật trong Firebase Console.',
      'account-exists-with-different-credential' => 'Email này đã dùng phương thức đăng nhập khác. Hãy đăng nhập bằng phương thức đã đăng ký.',
      'popup-blocked' => 'Trình duyệt đã chặn cửa sổ đăng nhập Google. Vui lòng cho phép cửa sổ bật lên.',
      'invalid-api-key' => 'Cấu hình Firebase chưa hợp lệ. Thay google-services.json và build lại.',
      _ => 'Firebase: ${error.message ?? error.code}',
    };
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
