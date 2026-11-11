# Đã bỏ xác nhận email bắt buộc

Theo yêu cầu ngày 11/11/2026, PawPals không còn chặn tài khoản chưa xác nhận email và không tự gọi dịch vụ OTP khi đăng ký/đăng nhập. Tài khoản cũ đăng nhập lại vào ứng dụng trực tiếp. Có thêm đăng nhập Google bằng Firebase Auth, không cần Cloud Functions hoặc SMTP; xem [cấu hình Google](google-sign-in.md).

Firestore Rules chỉ yêu cầu phiên Firebase Auth hợp lệ, giữ kiểm tra chủ sở hữu theo UID và phân quyền quản trị. Ứng dụng không tự sửa trạng thái `emailVerified` trên máy chủ.

Các file `functions/otp.js`, màn hình xác nhận và `tools/configure_email.ps1` được giữ để tham khảo; không cần chạy hoặc triển khai chúng cho luồng đăng nhập hiện tại. Tài liệu trước đây yêu cầu Blaze/SMTP cho OTP không còn là bước thiết lập đăng nhập.

Logo ứng dụng nằm ở `lib/widgets/pawpals_logo.dart`; xuất lại biểu tượng bằng `flutter test tools/render_brand_icons.dart`.
