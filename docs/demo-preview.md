# Xem dữ liệu mẫu trên Android Emulator

Bản xem thử dùng project cục bộ `demo-pawpals`. Tài khoản `demo@pawpals.test`, mật khẩu `PawPals123!`, đã xác nhận email và có quyền quản trị trong Auth Emulator.

Tại thư mục dự án, mở một PowerShell và giữ tiến trình này chạy:

```powershell
firebase emulators:start --config firebase.integration.json --project demo-pawpals --only "firestore,auth"
```

Trong PowerShell khác, nạp dữ liệu và mở app trên máy ảo Android đang chạy:

```powershell
node tools/seed_demo.cjs
flutter run -d emulator-5554 --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=FIRESTORE_EMULATOR_PORT=8180 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9199
```

Đăng nhập bằng tài khoản demo. Dữ liệu gồm 3 thú cưng (Bông, Milo, Mochi), 6 bản ghi sức khỏe, 5 lịch nhắc, 12 sản phẩm, 3 phòng khám mô phỏng và 3 bài hướng dẫn sử dụng. Cho phép thông báo để thử lịch nhắc. Trung tâm quản trị nằm trong tab Tài khoản.

Để thử yêu cầu quyền quản trị, đăng nhập `member@pawpals.test` với cùng mật khẩu `PawPals123!`, mở **Tài khoản → Yêu cầu quyền quản trị**. Đăng nhập lại bằng `demo@pawpals.test` để xem và duyệt tại **Trung tâm quản trị → Yêu cầu cấp quyền**. Tài khoản `applicant@pawpals.test` có sẵn một yêu cầu mẫu; script giữ nguyên kết quả đã duyệt khi chạy lại.

Script chỉ gọi các cổng localhost 8180/9199, giữ nguyên document đã tồn tại khi chạy lại và không nhập dữ liệu vào Firebase thật. Thông tin sức khỏe/phòng khám được đánh dấu minh họa; phòng khám không có số điện thoại thực tế. Dữ liệu emulator nằm trong bộ nhớ, vì vậy hãy chạy lại script sau khi khởi động lại Firebase Emulator. Không chạy bộ test rules trong lúc xem demo vì bộ test đó xóa dữ liệu trong cùng project emulator.

Để chạy lại bản dùng Firebase thật, dừng bản demo rồi chạy `flutter run -d emulator-5554` không kèm các tham số emulator.
