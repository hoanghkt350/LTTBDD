# PawPals

## Quản trị và phân quyền

Đã bổ sung vai trò người dùng/quản trị viên, kiểm tra quyền bằng Firebase custom claims và màn hình **Tài khoản → Trung tâm quản trị**. Quản trị viên quản lý sản phẩm, đơn hàng, phòng khám, bài viết và xem hồ sơ tài khoản. Xem [hướng dẫn sử dụng, cấp/thu hồi quyền](docs/admin-management.md).

## Cập nhật xác nhận email và logo

Đã bổ sung đăng ký bằng mã OTP 6 số, màn hình xác nhận email, giới hạn gửi/nhập sai, chính sách mật khẩu đăng ký và logo mới. **Để gửi mã OTP cần kích hoạt Cloud Functions và SMTP**; project hiện chưa bật thanh toán. Khi dịch vụ OTP chưa hoạt động, có thể xác nhận bằng liên kết email của Firebase Auth. Rules đã yêu cầu email được xác nhận. Xem [hướng dẫn cấu hình và kiểm thử](docs/email-verification.md).

Ứng dụng Flutter cho Android: hồ sơ thú cưng, sổ sức khỏe, nhắc lịch hàng ngày, cửa hàng và đơn hàng COD.

## Firebase của dự án này

- Project ID: `dalttbdd-b3e19` ([Firebase Console](https://console.firebase.google.com/project/dalttbdd-b3e19/overview)).
- Android app: `vn.edu.hutech.pawpals_app`.
- Cấu hình thật đã được tải vào `android/app/google-services.json`; `.firebaserc` trỏ mặc định đến project này.
- Email/Password đã bật; Firestore Standard ở `asia-southeast1`.
- Firestore Rules và indexes đã triển khai; 6 sản phẩm mẫu đã nhập. Script nhập liệu giữ nguyên sản phẩm đã tồn tại.
- Backend thật đã được kiểm tra: Auth, đọc/ghi hồ sơ, đơn hàng, hoàn kho và phân quyền. Dữ liệu/tài khoản kiểm thử được xóa sau khi chạy, không sửa tồn kho sản phẩm hiện có.
- Kiểm thử Android với project thật cũng đã qua: khởi tạo cấu hình native, đăng ký tài khoản tạm và hiển thị danh mục trên giao diện. Tài khoản tạm được xóa sau kiểm thử.

Các bước tạo project bên dưới dành cho việc cấu hình lại hoặc chuyển sang project khác.

## 1. Tạo Firebase thật

1. Mở https://console.firebase.google.com/ → Create a project → đặt tên PawPals. Có thể tắt Google Analytics.
2. Project settings → General → lấy Project ID.
3. Thêm ứng dụng Android, package: `vn.edu.hutech.pawpals_app`.
4. Tải `google-services.json`, thay file `android/app/google-services.json` trong dự án.
5. Authentication → Sign-in method → Email/Password → Enable → Save.
6. Firestore Database → Create database → Standard → Production mode. Chọn khu vực gần người dùng (ví dụ Singapore).
7. Không dùng file cấu hình chứa API key “Example…” đã có sẵn trước đây. App sẽ báo thiết lập khi phát hiện file mẫu.

Tài liệu chính thức: https://firebase.google.com/docs/flutter/setup

## 2. Triển khai dữ liệu và rules

Chạy PowerShell tại thư mục dự án:

```powershell
firebase login
firebase projects:list
firebase deploy --only firestore:rules,firestore:indexes --project dalttbdd-b3e19
dart run tools/export_catalog.dart
node tools/seed_catalog.cjs dalttbdd-b3e19
flutter pub get
flutter run
```

Nếu chuyển dự án, thay `dalttbdd-b3e19` bằng Project ID mới. Script nhập 6 sản phẩm mẫu, không ghi đè sản phẩm/tồn kho đã có. Script dùng tài khoản Firebase CLI trên máy, không yêu cầu private key, không in token. Không bật Test mode hoặc thay rules bằng quyền truy cập công khai.

Android dùng cấu hình native từ google-services.json. Chưa cấu hình hoặc xác nhận iOS/Web/Windows. Nếu mở rộng nền tảng, chạy FlutterFire CLI và bổ sung FirebaseOptions theo tài liệu chính thức; phần SQLite/nhắc lịch hiện ưu tiên Android.

## 3. Chức năng

- Đăng ký riêng với đăng nhập; xác thực Firebase Auth thật, giữ phiên SDK, đặt lại mật khẩu qua email.
- Chỉnh sửa tên, điện thoại, địa chỉ; không tạo thông tin cá nhân giả.
- Thêm/sửa/xóa hồ sơ thú cưng, ảnh thumbnail (tối đa 180 KB) đồng bộ cùng hồ sơ qua Firestore; không cần Storage hay billing.
- Thêm/sửa/xóa sổ sức khỏe, ngày thực hiện, ngày hẹn, bác sĩ, chi phí và ghi chú.
- Nhắc hàng ngày: thêm/sửa/xóa/bật/tắt, yêu cầu quyền thông báo, tự đặt lại lịch sau khi khởi động thiết bị.
- SQLite riêng từng UID, giao dịch lưu dữ liệu và outbox nguyên tử. Nút Đồng bộ đẩy từng thay đổi thật lên Firestore và kéo dữ liệu của tài khoản về. Đăng nhập trên máy mới → Đồng bộ để khôi phục.
- Tìm kiếm/lọc sản phẩm; giỏ hàng riêng theo tài khoản được lưu khi tắt ứng dụng; kiểm soát tồn kho và số lượng.
- FREESHIP miễn phí vận chuyển; PAWPALS10/HUTECH10 giảm 10%; miễn phí vận chuyển từ 300.000đ.
- Đơn COD: nhập người nhận, điện thoại và địa chỉ, xác nhận; transaction kiểm tra giá và trừ tồn kho; lịch sử thời gian thực; hủy đơn chờ xác nhận và hoàn kho nguyên tử.
- Tối đa 5 loại sản phẩm/đơn để giữ trong giới hạn số lần đọc document của Firestore Security Rules. Mỗi loại tối đa 99.
- Thông tin phòng khám từ Firestore: tìm kiếm, lọc 24/7, gọi điện và mở Google Maps. Không giả lập khoảng cách GPS.
- Bài viết từ Firestore: mở và đọc đầy đủ nội dung.

## 4. Cấu trúc Firestore và quản trị

- users/{uid}: uid, email, displayName, phoneNumber, address, avatarUrl, membershipLevel (STANDARD).
- users/{uid}/pets/{id}: dữ liệu Pet theo tên trường trong Pet.toMap().
- users/{uid}/health_records/{id}: dữ liệu HealthRecord.toMap().
- users/{uid}/reminders/{id}: dữ liệu Reminder.toMap().
- products/{id}: xem tools/catalog.json (id, name, category, petTarget, price, originalPrice, stock, imageUrl, description, ...).
- orders/{id}: người nhận, items (map theo product ID), tổng tiền, trạng thái và server timestamp.
- clinics/{id}: name, address, latitude (number), longitude (number), phone, isOpen24_7 (boolean), openHours, services (array).
- articles/{id}: title, category, author, publishedAt (chuỗi ngày), thumbnailUrl, summary, content, readTimeMinutes (number).

Chủ dự án quản lý danh mục, phòng khám, nội dung và trạng thái đơn hàng qua Firebase Console. Client không có quyền tự đổi giá, tự nâng hạng thành viên hoặc xem đơn người khác. Có thể chuyển trạng thái đơn trong Console từ “Chờ xác nhận” sang “Đang giao”, “Hoàn thành”. Không đổi đơn sang “Đã hủy” bằng tay: thao tác hủy trong app sẽ hoàn tồn kho trong transaction.

Không nhập dữ liệu phòng khám giả làm thông tin cấp cứu thật. Hiện không tự nạp các số điện thoại và bài viết y tế mẫu của bản cũ. Chủ dự án cần cung cấp thông tin đã xác minh trước khi sử dụng.

## 5. Offline và giới hạn

- Sửa hồ sơ và nhắc lịch được lưu SQLite trước. Bấm Đồng bộ khi có mạng; thất bại vẫn giữ outbox để thử lại. App tự thử đồng bộ khi mở phiên.
- Không tự chuyển lỗi đăng nhập/đặt hàng thành thành công. Checkout cần kết nối với server.
- Xung đột cùng document khi hai thiết bị chỉnh sửa offline: phiên đồng bộ sau ghi đè document đó. Đồng bộ trước khi chuyển thiết bị; chưa có màn hình giải quyết xung đột.
- Xóa được lưu bằng tombstone trên cloud để các thiết bị nhận biết. Dữ liệu demo của database cũ được giữ nguyên trên máy, không tự gán cho tài khoản thật.
- Ảnh được nén thành thumbnail và lưu vào document, không phải kho lưu ảnh gốc.
- Lịch nhắc dùng giờ địa phương của thiết bị, đặt lịch inexact để không cần quyền exact alarm. Android có thể trì hoãn do tiết kiệm pin; nếu force-stop, mở lại app để lập lịch. Đăng xuất tạm dừng thông báo trên thiết bị. Chưa có push từ server.
- COD không thu tiền online. Không có tích hợp cổng thanh toán hoặc vận chuyển thật.
- Bản release hiện dùng signing debug của đồ án; cần keystore riêng trước khi phát hành.

## 6. Kiểm tra

Chạy tự động toàn bộ test dữ liệu (máy ảo `emulator-5554` đang mở và ở màn hình đăng nhập; Firebase CLI đã đăng nhập):

```powershell
node tools/run_data_tests.cjs
```

Lệnh này chạy test Flutter, Firestore Rules, đồng bộ và giao diện Android, rồi kiểm tra Firebase thật bằng tài khoản/dữ liệu tạm. Dữ liệu tạm được xóa sau kiểm tra. Cuối cùng script build, cài và mở lại app bình thường trên máy ảo. Kết quả ở `build/data-tests/latest.md`, JSON ở `build/data-tests/latest.json`, log riêng cho từng bước. Nếu một bước lỗi, dùng `node tools/run_data_tests.cjs --retry-failed` để chạy lại các bước chưa qua và giữ kết quả đã qua của cùng lần kiểm tra.

```powershell
flutter analyze --no-pub
flutter test --no-pub
npm --prefix tools ci
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
flutter build apk --debug
```

Kiểm thử tích hợp SDK Firebase và giao diện trên Android Emulator (thiết bị emulator-5554 đã mở):

```powershell
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only firestore,auth "node tools/android_smoke.cjs"
```

Kiểm thử này dùng Firebase app có tên riêng và project demo-pawpals, cổng Firestore 8180/Auth 9199. Không sử dụng dữ liệu project thật. Chỉ bật chế độ emulator bằng dart-define trong bản debug.

Đã kiểm tra ngày 06/11/2026: 15 test Flutter, 10 test Firestore Rules và 2 test tích hợp Android với emulator đều qua. Test Android bao gồm SDK Auth, đồng bộ SQLite/Firestore, đặt/hủy đơn, đặt lịch thông báo và đăng ký/thêm hồ sơ qua giao diện. Phân tích mã không có lỗi/cảnh báo. Backend thật `dalttbdd-b3e19` đã được kiểm tra bằng SDK Firebase; báo cáo nằm trong `build/firebase-verification.json`.

Kiểm tra backend thật bằng tài khoản CLI chủ dự án (tạo và tự xóa tài khoản, sản phẩm và đơn hàng tạm):

```powershell
node tools/verify_firebase.cjs dalttbdd-b3e19
```

Kiểm tra cấu hình native Android và danh mục thật trên máy ảo, tự xóa tài khoản tạm sau kiểm thử:

```powershell
flutter test integration_test/live_firebase_test.dart --no-pub -d emulator-5554 --dart-define=LIVE_FIREBASE_PROJECT=dalttbdd-b3e19
```

Các test SQLite kiểm tra outbox, không ghi đè thay đổi chưa gửi và xóa liên quan. Test giỏ kiểm tra voucher, tồn kho, lưu phiên và khóa checkout. Test rules kiểm tra phân quyền, sửa giá/tổng tiền, tồn kho, tạo/hủy đơn và giỏ nhiều sản phẩm.

Kịch bản kiểm tra trên Android sau cấu hình Firebase:
1. Đăng ký hai tài khoản khác nhau; thử mật khẩu sai.
2. Tài khoản A thêm thú cưng/ảnh/sổ sức khỏe/lịch nhắc, Đồng bộ.
3. Đăng xuất → B không nhìn thấy hồ sơ/giỏ/đơn của A.
4. A đăng nhập lại trên thiết bị khác → Đồng bộ → khôi phục hồ sơ và lịch.
5. Tắt mạng → sửa hồ sơ → khởi động lại → dữ liệu vẫn còn → bật mạng → Đồng bộ.
6. Cấp quyền thông báo, tạo lịch cách giờ hiện tại vài phút, đưa app xuống nền.
7. Đặt đơn COD, xem lịch sử, hủy → kiểm tra tồn kho trở lại.
8. Hai thiết bị đặt sản phẩm còn 1: chỉ một đơn được xác nhận.
