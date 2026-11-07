# Xác nhận email bằng mã OTP

Mã nguồn đã có luồng đăng ký → nhập mã 6 số → vào ứng dụng. Gmail là địa chỉ nhận email; cũng có thể dùng nhà cung cấp email khác. Tài khoản cũ chưa xác nhận sẽ đi qua bước xác nhận khi đăng nhập lại.

## Kích hoạt gửi email thật

Project `dalttbdd-b3e19` hiện chưa gắn thanh toán (đã kiểm tra ngày 07/11/2026). Cần chủ project bật gói Blaze trước khi triển khai Cloud Functions. Chưa triển khai rules mới lên production vì cần dịch vụ gửi mã hoạt động trước để người dùng có thể xác nhận.

1. Bật Blaze tại [Firebase Console](https://console.firebase.google.com/project/dalttbdd-b3e19/usage/details). Đặt cảnh báo ngân sách theo nhu cầu.
2. Chuẩn bị một Gmail dùng để gửi mã, bật xác minh 2 bước và tạo [mật khẩu ứng dụng Google](https://support.google.com/accounts/answer/185833). Không dùng mật khẩu đăng nhập Gmail. Tài khoản Workspace có thể bị quản trị viên hạn chế tính năng này; khi đó cấu hình SMTP khác trong Secret Manager.
3. Tại thư mục dự án, chạy:

   ```powershell
   firebase login
   npm --prefix functions ci
   powershell -ExecutionPolicy Bypass -File tools/configure_email.ps1
   firebase deploy --only functions:pawpals-auth --project dalttbdd-b3e19
   ```

   Script hỏi địa chỉ gửi và mật khẩu ứng dụng qua đầu vào ẩn, tạo khóa HMAC ngẫu nhiên và lưu cấu hình vào secret `PAWPALS_MAIL_CONFIG`. File tạm được xóa trong `finally`. Không nhập mật khẩu vào chat, Git, `--dart-define` hoặc mã Flutter. Khi thay secret, triển khai lại hai functions để sử dụng phiên bản mới.

4. Kiểm tra gửi mã đến một hộp thư của bạn và nhập mã. Sau đó triển khai rules bắt buộc email đã xác nhận cùng indexes:

   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes --project dalttbdd-b3e19
   flutter build apk --debug
   ```

5. Firebase Console → Authentication → Settings → Password policy: bật chế độ **Require**, tối thiểu 10 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt. Giữ tùy chọn không bắt tài khoản cũ đổi mật khẩu khi đăng nhập nếu cần tương thích. Ứng dụng đã kiểm tra chính sách này khi đăng ký; cấu hình Console áp dụng chính sách cho cả yêu cầu gửi trực tiếp đến Firebase Auth.

Địa chỉ functions: vùng `asia-southeast1`, tên `sendEmailVerificationCode` và `verifyEmailVerificationCode`. Ứng dụng tự dùng project của Firebase native hiện tại. Secret là JSON gồm `host`, `port` (465 hoặc 587), `user`, `password`, `otpSecret` (ít nhất 32 ký tự ngẫu nhiên). SMTP luôn xác thực TLS.

## Cơ chế bảo vệ

- Mã 6 số sinh bằng bộ sinh ngẫu nhiên mật mã, hiệu lực 10 phút; chỉ lưu HMAC-SHA256 gắn với UID, email và nonce trên máy chủ.
- Tối đa 5 lần nhập sai mỗi mã; các lần nhập đồng thời vẫn được cộng trong transaction. Gửi lại thay mã cũ.
- Chờ 60 giây giữa hai lần gửi; tối đa 5 email/giờ/địa chỉ và 20 email/giờ/IP. Ngân sách theo email vẫn giữ khi xóa rồi tạo lại tài khoản. IP chỉ được lưu dưới dạng HMAC.
- Máy chủ chỉ gửi đến email trong Firebase Auth và chỉ Admin SDK được cập nhật `emailVerified`. Client không đọc/ghi được kho mã và bộ đếm.
- Tài khoản chưa xác nhận không được tạo session dữ liệu trong ứng dụng; rules mới từ chối đọc/ghi dữ liệu và đơn hàng. Sau xác nhận, ứng dụng tải lại ID token để rules thấy `email_verified`.
- Đăng ký có kiểm tra mật khẩu và ô nhập lại; đặt lại mật khẩu không tiết lộ email có tồn tại. Android tắt sao lưu tự động và bỏ quyền gọi điện trực tiếp/vị trí không sử dụng.

Đây là xác nhận email khi đăng ký, không phải xác thực hai yếu tố cho mỗi lần đăng nhập. Nếu phát hành công khai với lưu lượng lớn, cân nhắc dịch vụ SMTP chuyên dụng thay Gmail và triển khai Firebase App Check với Play Integrity theo [tài liệu Firebase](https://firebase.google.com/docs/app-check/flutter/default-providers).

## Kiểm thử

```powershell
npm --prefix functions test
flutter test --no-pub
flutter analyze --no-pub
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
```

Test máy chủ dùng hộp thư giả lập trong bộ nhớ, không gửi email thật. Kiểm tra việc nhận email thật chỉ thực hiện được sau khi hoàn tất cấu hình SMTP và triển khai. Các kiểm thử dữ liệu Android dùng Admin API của Auth Emulator để xác nhận tài khoản kiểm thử, không có cơ chế bỏ qua xác nhận trong ứng dụng production.

Kết quả kiểm tra ngày 07/11/2026: 27 test Flutter, 13 test máy chủ OTP, 12 test Firestore Rules và 2 test Android đều qua. `flutter analyze --no-pub` không có lỗi/cảnh báo; `npm audit --prefix functions` không phát hiện lỗ hổng trong các dependency đã khóa phiên bản. Chưa kiểm thử nhận thư qua SMTP thật.

Logo mới được vẽ bằng vector trong `lib/widgets/pawpals_logo.dart`. Để xuất lại biểu tượng Android, iOS, macOS, Windows và Web:

```powershell
flutter test tools/render_brand_icons.dart
```

Ảnh gốc 1024px nằm tại `assets/branding/pawpals-logo.png`.

Tài liệu nền tảng: [callable functions](https://firebase.google.com/docs/functions/callable), [Secret Manager](https://firebase.google.com/docs/functions/config-env#secret_parameters), [Admin SDK và emailVerified](https://firebase.google.com/docs/auth/admin/manage-users), [chính sách mật khẩu](https://firebase.google.com/docs/auth/flutter/password-auth#recommended_enable_password_policy).
