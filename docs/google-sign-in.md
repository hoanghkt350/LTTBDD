# Đăng nhập Google

PawPals cho phép đăng nhập/đăng ký bằng email và mật khẩu hoặc nút **Tiếp tục với Google**. Không yêu cầu nhập OTP hay mở liên kết xác nhận email trước khi vào ứng dụng. Không cần triển khai Cloud Functions hoặc SMTP cho đăng nhập Google.

## Cấu hình Firebase cho Android

1. Mở [Authentication → Sign-in method](https://console.firebase.google.com/project/dalttbdd-b3e19/authentication/providers), thêm **Google**, bật phương thức này, chọn email hỗ trợ và lưu. Firebase sẽ tạo OAuth client của dự án. Không cần bật Blaze cho bước này.
2. Chạy trong thư mục dự án:

   ```powershell
   node tools/configure_google.cjs
   ```

   Script dùng phiên `firebase login` hiện có, đăng ký SHA-1/SHA-256 của `~/.android/debug.keystore`, kiểm tra Google đã bật rồi tải lại `android/app/google-services.json` có web OAuth client. Không ghi OAuth client secret vào app hay log. Chạy lại an toàn khi cấu hình đã tồn tại.
3. Triển khai Rules cho phép tài khoản đã đăng nhập truy cập dữ liệu của mình:

   ```powershell
   firebase deploy --only firestore:rules --project dalttbdd-b3e19
   ```

4. Build và cài lại app:

   ```powershell
   flutter pub get
   flutter build apk --debug
   ```

   APK: `build/app/outputs/flutter-apk/app-debug.apk`. Bản release hiện cũng dùng debug signing theo cấu hình Gradle. Khi đổi sang khóa ký phát hành hoặc Play App Signing, thêm SHA của khóa mới trong Firebase Project settings trước khi phát hành.

## Hành vi

- Nút Google có ở cả màn hình đăng nhập và đăng ký; không cần nhập biểu mẫu email/mật khẩu trước.
- Android dùng `google_sign_in` rồi trao đổi ID token với Firebase Auth. Web dùng popup của Firebase Auth. Lựa chọn tài khoản được mở lại ở lần đăng nhập tiếp theo.
- Hủy chọn tài khoản không hiện lỗi. Trong lúc xử lý, các nút đăng nhập bị khóa để tránh yêu cầu trùng.
- Hồ sơ lấy tên, email, ảnh từ Firebase Auth lần đầu; giữ dữ liệu hồ sơ đã lưu ở những lần đăng nhập sau. Quyền quản trị vẫn lấy từ claim hoặc yêu cầu được duyệt, không lấy theo địa chỉ Gmail.
- Email/mật khẩu vẫn dùng được, gồm tài khoản cũ chưa xác nhận email. Không tự đánh dấu `emailVerified` trên máy chủ.
- Nếu Firebase báo email đã dùng phương thức khác, ứng dụng yêu cầu dùng phương thức đã đăng ký; không tự gộp dữ liệu của hai tài khoản.

Dự án hiện được cấu hình và build cho Android. iOS/macOS cần đăng ký Firebase app tương ứng, thêm `GIDClientID`, `GIDServerClientID` và URL scheme trong `Info.plist` trước khi chạy Google. Web cần Firebase Web config và authorized domain. Windows/Linux dùng email/mật khẩu, không hiển thị nút Google.

## Kiểm thử

```powershell
flutter analyze --no-pub
flutter test --no-pub
npm --prefix functions test
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
```

Kiểm tra Google thật trên thiết bị có Google Play services: chọn tài khoản, vào màn hình chính, đăng xuất, chọn tài khoản khác và thử hủy hộp thoại. Việc chọn tài khoản Google cần người dùng thao tác; kiểm thử giả lập không chứng minh OAuth production đã hoạt động.

## Xuất APK cho điện thoại

```powershell
powershell -ExecutionPolicy Bypass -File tools/export_apk.ps1
python tools/verify_apk_startup.py exports/PawPals-Google-v2.apk
```

Script xuất bản release từ `lib/main.dart`, tăng mã phiên bản lên 2 và chép sang `exports/PawPals-Google-v2.apk` sau khi build thành công, kiểm tra SHA-256 của bản sao. Flutter được phép tạo lại đăng ký plugin cho chế độ release, tránh tham chiếu plugin chỉ dành cho kiểm thử từ bản debug cũ.

Người dùng báo màn hình đen trên Vivo. Bản mới dùng release AOT và tắt Impeller để thử bộ vẽ dự phòng theo [hướng dẫn Flutter](https://docs.flutter.dev/perf/impeller#android). Chưa có log trực tiếp từ Vivo để xác nhận nguyên nhân. Trên máy ảo, Firebase và cây widget đăng nhập vẫn hoạt động nhưng ảnh chụp bị đen; kiểm tra đối chứng cho thấy cả ứng dụng Cài đặt Android cũng đen, nên cần khởi động lại máy ảo trước khi kết luận về APK.

`verify_apk_startup.py` dùng Android SDK ADB và Python Pillow, cài đè APK trên `emulator-5554`, mở app, chụp bề mặt Android và yêu cầu hai khung hình liên tiếp có nội dung sáng. Không xóa dữ liệu ứng dụng. Nếu màn hình đen, script kiểm tra thêm Cài đặt Android để phát hiện lỗi hiển thị chung của máy ảo. Ảnh, báo cáo và log được lưu trong `build/diagnostics/release-startup`. Đây là kiểm tra hiển thị lúc khởi động; vẫn cần thử trên máy Vivo thực tế.

Tham khảo: [Firebase Auth cho Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth), [google_sign_in](https://pub.dev/packages/google_sign_in), [cấu hình Android](https://pub.dev/packages/google_sign_in_android).

## Trạng thái ngày 11/11/2026

Google đã bật trên `dalttbdd-b3e19`. SHA-1/SHA-256 của debug signing đã đăng ký và `google-services.json` đã tải lại, có cả Android OAuth client khớp chữ ký và web OAuth client. Firestore Rules mới đã triển khai thành công.

Đã qua 65 kiểm thử Flutter, 35 kiểm thử máy chủ và 31 kiểm thử Firestore Rules. `node tools/verify_firebase.cjs dalttbdd-b3e19` kiểm chứng tài khoản email chưa xác nhận đọc/ghi hồ sơ, thú cưng, sổ sức khỏe, nhắc lịch, đọc sản phẩm và đặt/hủy đơn trên Firebase thật; truy cập chéo tài khoản và phiên chưa đăng nhập bị từ chối. Tài khoản và dữ liệu tạm được dọn sau kiểm thử. Chưa thực hiện chọn tài khoản Google thật trên điện thoại.

`flutter analyze --no-pub` không có lỗi/cảnh báo. `flutter build apk --debug --no-pub` thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`; resource `default_web_client_id` khớp với web OAuth client trong cấu hình Firebase.
