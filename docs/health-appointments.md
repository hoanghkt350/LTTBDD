# Lịch tiêm và tái khám theo ngày hẹn

## Sử dụng

1. Mở **Thú cưng → hồ sơ của bé → Sổ sức khỏe** và thêm hoặc sửa hồ sơ.
2. Chọn **Ngày hẹn tiếp theo**, bật **Nhắc lịch hẹn** và chọn giờ nhắc (mặc định 08:00). Cho phép thông báo khi ứng dụng yêu cầu.
3. Ứng dụng đặt hai thông báo một lần: trước một ngày và vào ngày hẹn, cùng giờ đã chọn. Những thời điểm đã qua được bỏ qua; thông báo không tự lặp lại hằng ngày.
4. Xem lịch đang chờ ở **Trang chủ → Lịch tiêm & tái khám** (ba lịch gần nhất) hoặc mục **Thú cưng** (toàn bộ lịch đang chờ). Chạm lịch để mở đúng hồ sơ thú cưng.
5. Sau khi thực hiện lịch hẹn, mở hồ sơ và chọn **Đánh dấu đã thực hiện**. Thông báo cho lịch đó được hủy. Chọn **Mở lại lịch hẹn** để khôi phục nếu đánh dấu nhầm.

Trạng thái gồm **Đã lên lịch** (còn hơn bảy ngày), **Sắp đến hạn** (còn một đến bảy ngày), **Đến hạn hôm nay**, **Quá hạn** và **Đã thực hiện**. Trạng thái dựa trên ngày lịch của thiết bị. Đánh dấu hoàn tất chỉ hoàn tất lịch hẹn; người dùng thêm bản ghi sức khỏe mới để lưu lần khám/tiêm thực tế và lịch hẹn kế tiếp.

## Lưu dữ liệu và thông báo

- Bổ sung `next_due_reminder_enabled`, `next_due_reminder_time` (`HH:mm`) và `next_due_completed` vào bản ghi sức khỏe. Bản ghi cũ mặc định bật nhắc lúc 08:00 và chưa hoàn tất nếu có ngày hẹn.
- Dữ liệu tiếp tục lưu SQLite và outbox nguyên tử rồi đồng bộ vào `users/{uid}/health_records/{id}` bằng luồng đồng bộ hiện có. Không thay schema SQLite hoặc tạo bản ghi nhắc hằng ngày trùng lịch hẹn. Firestore Rules hiện có đã cho phép các trường này trong dữ liệu của chủ tài khoản.
- Sửa ngày hẹn tự bỏ trạng thái hoàn tất của ngày hẹn cũ. Sửa thông tin khác vẫn giữ trạng thái hoàn tất. Tắt nhắc, bỏ ngày hẹn, hoàn tất, xóa bản ghi hoặc xóa thú cưng đều cập nhật/hủy thông báo liên quan.
- Lịch hẹn và nhắc hằng ngày dùng cùng một kế hoạch, cấp ID thông báo riêng để không ghi đè nhau. Lịch được đặt lại sau đồng bộ hoặc khi quay lại ứng dụng; thay đổi múi giờ thiết bị được cập nhật khi đặt lại lịch. Đăng xuất hủy các thông báo của tài khoản trên thiết bị.
- Thông báo chạy cục bộ, không cần Cloud Functions hoặc SMTP. Android có thể trì hoãn do tiết kiệm pin; nếu force-stop, cần mở lại app để đặt lại lịch. Không cam kết thông báo đúng phút. Phần iOS vẫn chưa được cấu hình/kiểm chứng; kế hoạch giới hạn 64 thông báo chờ, ưu tiên nhắc hằng ngày rồi lịch hẹn gần nhất.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only "firestore,auth" "node tools/android_smoke.cjs --features"
```

Test kiểm tra tương thích dữ liệu cũ, trạng thái theo ngày, đổi giờ mùa hè, bỏ qua lịch quá hạn/đã hoàn tất, ID thông báo không trùng, hoàn tất/mở lại được lưu vào outbox, luồng nhập lịch hẹn trên màn hình rộng 320/800 và quyền riêng tư khi đồng bộ. Test Android kiểm tra lịch hẹn và lịch hàng ngày cùng tồn tại, hoàn tất/đổi ngày/xóa hủy đúng thông báo, đồng bộ trạng thái lên Firestore và truy vấn tổng hợp thật qua SDK.

## Kết quả ngày 08/11/2026

- Toàn bộ 54 test Flutter và một test bổ sung riêng cho việc sửa ngày hẹn đã qua; 28 test Firestore Rules đã qua.
- `flutter analyze --no-pub` và kiểm tra riêng các file giao diện/test cập nhật cuối không có lỗi/cảnh báo.
- Test tích hợp Android `features_test.dart` đã qua: kiểm chứng tổng hợp đơn hàng, loại sản phẩm ngừng bán khỏi cảnh báo kho, đăng ký/hủy lịch hẹn, lưu trạng thái hoàn tất lên Firestore và chặn truy vấn sau khi thu hồi quyền.
- Index tổng hợp trên Firebase thật `dalttbdd-b3e19` đã `READY`; truy vấn kiểm chứng chỉ đọc đã thành công.
- Đã build APK debug bình thường với Firebase thật, không chứa cấu hình emulator trong luồng chạy mặc định.
