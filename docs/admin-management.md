# Phân quyền và quản trị PawPals

Ứng dụng có hai vai trò. Tài khoản thông thường chỉ quản lý hồ sơ, thú cưng và đơn hàng của mình. Quản trị viên có thêm mục **Tài khoản → Trung tâm quản trị** để quản lý sản phẩm, đơn hàng, phòng khám, bài viết và xem danh sách hồ sơ tài khoản.

Quyền quản trị lấy từ custom claim `admin: true` trong ID token do Firebase ký. Không lấy quyền từ email được ghi cứng trong app, thông tin hồ sơ, hạng thành viên hoặc dữ liệu lưu trên máy. Firestore Rules kiểm tra quyền cho từng yêu cầu; mở trực tiếp màn hình hay sửa giao diện không cấp quyền truy cập dữ liệu.

## Tài khoản quản trị đầu tiên

Đã cấp custom claim cho `hoangnguyen110605@gmail.com` theo yêu cầu của chủ dự án. Email vẫn phải được xác nhận. Sau khi cài bản mới:

1. Đăng nhập bằng tài khoản trên.
2. Nếu dịch vụ mã OTP chưa hoạt động, chọn **Xác nhận bằng liên kết email**, mở liên kết trong Gmail, quay lại ứng dụng và bấm **TÔI ĐÃ XÁC NHẬN EMAIL**. Lựa chọn này dùng dịch vụ xác nhận email có sẵn của Firebase Auth, không cần SMTP riêng.
3. Vào **Tài khoản → Trung tâm quản trị**. Nếu phiên đăng nhập cũ chưa có quyền mới, đăng nhập lại hoặc bấm biểu tượng cập nhật ở thẻ vai trò tài khoản.

Không tự đặt `emailVerified = true` để bỏ qua việc xác nhận quyền sở hữu email. Luồng mã OTP 6 số vẫn cần Cloud Functions và cấu hình SMTP như [hướng dẫn email](email-verification.md).

## Các thao tác quản trị

| Mục | Thao tác |
| --- | --- |
| Sản phẩm | Thêm/sửa tên, danh mục, giá, tồn kho, ảnh, mô tả; bật/tắt nổi bật và ngừng/mở bán. |
| Đơn hàng | Xem đơn của khách, người nhận, sản phẩm, tổng tiền; chuyển Chờ xác nhận → Đang giao → Hoàn thành. |
| Hủy đơn | Chỉ hủy đơn Chờ xác nhận; hoàn kho trong cùng transaction, không hoàn lần thứ hai. |
| Phòng khám | Thêm/sửa/xóa thông tin đã xác minh, giờ mở cửa, tọa độ, số điện thoại và dịch vụ. |
| Bài viết | Thêm/sửa/xóa chuyên mục, tác giả, ngày đăng, tóm tắt, nội dung và ảnh bìa. |
| Tài khoản | Xem tên, email, điện thoại, địa chỉ trong hồ sơ; không xem mật khẩu hay hồ sơ thú cưng riêng tư. |

Sản phẩm được ngừng bán thay vì xóa để đơn cũ vẫn có thể hoàn kho. Checkout kiểm tra lại trạng thái mở bán phía server. Khi quản trị viên chỉ sửa tên hoặc giá, ứng dụng không ghi đè tồn kho cũ; nếu sửa số lượng trong lúc có đơn làm thay đổi kho, ứng dụng yêu cầu tải lại trước khi lưu.

Danh sách có tìm kiếm trên dữ liệu đã tải, nút **Tải thêm**, bộ lọc trạng thái đơn và cập nhật thời gian thực. Khởi đầu 100 mục, có thể tải tối đa 5.000 mục mỗi lần mở danh sách.

## Cấp hoặc thu hồi quyền quản trị

Chỉ người có quyền quản lý Firebase Auth của project được chạy công cụ chủ dự án. Người dùng không có lựa chọn vai trò khi đăng ký và quản trị viên trong app không tự cấp quyền cho tài khoản khác.

```powershell
firebase login
node tools/manage_admin.cjs dalttbdd-b3e19 grant EMAIL_DA_DANG_KY
node tools/manage_admin.cjs dalttbdd-b3e19 revoke EMAIL_CAN_THU_HOI
```

Công cụ tra đúng email đã đăng ký, giữ nguyên các custom claim khác, không tạo tài khoản hay thay mật khẩu, không xác nhận email thay người dùng và không in OAuth token. Tài khoản nhận quyền cần đăng nhập lại hoặc cập nhật quyền trong app. ID token đã cấp có thể còn hiệu lực đến khi hết hạn (thường tối đa một giờ); app buộc làm mới token trước khi mở danh sách quản trị hoặc ghi dữ liệu.

Rules đã được triển khai lên `dalttbdd-b3e19`. Khi cập nhật lại rules, chạy:

```powershell
firebase deploy --only firestore:rules --project dalttbdd-b3e19
```

Phần phân quyền và quản trị này dùng Firebase Auth + Firestore trực tiếp, không cần triển khai Cloud Functions mới.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub
node --test tools/manage_admin.test.cjs
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only firestore,auth "node tools/android_smoke.cjs"
```

Các test xác nhận người dùng không thể tự nâng quyền, admin chưa xác nhận email không được truy cập, không sửa giá/tổng tiền trong đơn, không đảo trạng thái đơn kết thúc, hủy hoàn kho đúng một lần và vẫn xử lý được đơn năm loại sản phẩm. Test Android còn kiểm tra custom claim thật của Auth Emulator, sửa sản phẩm khi tồn kho thay đổi và thu hồi quyền.

Đã kiểm tra trên Firebase thật bằng `node tools/verify_admin.cjs dalttbdd-b3e19`: tài khoản thường không tự nâng quyền/sửa sản phẩm, admin đọc được hồ sơ khách nhưng không đọc hồ sơ thú cưng và OTP riêng tư, quyền bị thu hồi bị từ chối sau khi làm mới token. Script dùng hai tài khoản tạm và một sản phẩm ngừng bán tạm rồi tự dọn; báo cáo nằm ở `build/admin-verification.json`.

Kết quả ngày 07/11/2026: 33 test Flutter, 19 test Firestore Rules, 3 test công cụ cấp/thu hồi quyền và 3 test Android đều qua. `flutter analyze --no-pub` không có lỗi/cảnh báo. Rules đã triển khai thành công và kiểm chứng trên project thật; tài khoản Gmail quản trị đầu tiên vẫn cần tự xác nhận email.

Tài liệu chính thức: [custom claims và Security Rules](https://firebase.google.com/docs/auth/admin/custom-claims), [transaction và getAfter](https://firebase.google.com/docs/firestore/manage-data/transactions).
