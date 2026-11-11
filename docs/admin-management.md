# Phân quyền và quản trị PawPals

Ứng dụng có hai vai trò. Tài khoản thông thường chỉ quản lý hồ sơ, thú cưng và đơn hàng của mình. Quản trị viên có thêm mục **Tài khoản → Trung tâm quản trị** để quản lý sản phẩm, đơn hàng, phòng khám, bài viết và xem danh sách hồ sơ tài khoản.

Quyền quản trị được xác định bằng custom claim `admin: true` trong ID token do Firebase ký hoặc yêu cầu `admin_requests/{uid}` có trạng thái `approved` do một quản trị viên khác duyệt. Không lấy quyền từ email được ghi cứng, thông tin hồ sơ, hạng thành viên hoặc dữ liệu lưu trên máy. Firestore Rules kiểm tra cả hai cách cho từng yêu cầu; người dùng không thể tự ghi trạng thái được duyệt.

## Tài khoản quản trị đầu tiên

Đã cấp custom claim cho `hoangnguyen110605@gmail.com` theo yêu cầu của chủ dự án. Đăng nhập bằng tài khoản này, sau đó vào **Tài khoản → Trung tâm quản trị**. Nếu phiên cũ chưa có quyền mới, đăng nhập lại hoặc bấm biểu tượng cập nhật ở thẻ vai trò tài khoản.

Không yêu cầu xác nhận email trước khi đăng nhập hoặc dùng quyền đã được cấp. Google Sign-In dùng Firebase Auth; xem [hướng dẫn Google](google-sign-in.md). Quyền quản trị tiếp tục được kiểm tra theo UID và quyết định cấp quyền trên máy chủ.

## Các thao tác quản trị

Đơn online **MoMo** hiển thị trạng thái thanh toán và mã giao dịch. Chỉ đơn đã thanh toán trong production mới được giao/hoàn thành; đơn chờ trả tiền, thử nghiệm và cần đối soát bị chặn cả trên giao diện và Rules. Nút hủy COD không áp dụng cho MoMo đã trả tiền; xem [quy trình thanh toán và hoàn tiền](online-payments.md).

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

## Tổng quan hoạt động

Mở **Tài khoản → Trung tâm quản trị → Tổng quan**. Đây là mục mặc định khi vào trung tâm quản trị. Kéo xuống hoặc bấm nút tải lại để cập nhật:

- Tổng số đơn đang chờ xác nhận và đang giao; số đơn được tạo trong ngày.
- Tổng tiền và số đơn hoàn thành trong ngày/tháng hiện tại.
- Danh sách sản phẩm đang bán có tồn kho từ 0 đến 5, ưu tiên sản phẩm hết hàng. Hiển thị tối đa 20 dòng; số lượng cảnh báo vẫn tính toàn bộ kết quả.

Ngày/tháng được tính theo giờ trên thiết bị quản trị. Tổng tiền COD lấy `totalAmount` của đơn ở trạng thái **Hoàn thành**, gồm phí vận chuyển sau giảm giá, theo `statusUpdatedAt` (thời điểm hoàn thành). Đây là giá trị đơn hoàn thành, không phải lợi nhuận hay đối soát tiền thực nhận. Đơn chờ, đang giao, đã hủy và đơn cũ không có thời điểm hoàn thành không được cộng vào doanh thu. Ứng dụng không tự suy đoán ngày hoàn thành cho dữ liệu cũ.

Thống kê dùng `count`/`sum` phía Firestore trên toàn bộ kết quả phù hợp, không lấy tổng từ 100 đơn đầu trong danh sách. Cần có mạng để tải/làm mới; lỗi được hiển thị kèm nút thử lại. Màn hình được bảo vệ bằng quyền admin hiện có; không cấp thêm quyền xem sổ sức khỏe của khách hàng.

Triển khai index `orders(status, statusUpdatedAt, totalAmount)` trong `firestore.indexes.json` trước khi dùng trên project thật; đợi index chuyển sang trạng thái sẵn sàng:

```powershell
firebase deploy --only firestore:indexes --project dalttbdd-b3e19
node tools/verify_dashboard.cjs dalttbdd-b3e19
```

Lệnh kiểm chứng chỉ đọc trạng thái index và chạy một truy vấn tổng hợp trên project thật; không tạo/xóa tài khoản hoặc dữ liệu, không in token hay thông tin đơn hàng. Xem [tài liệu Firestore về truy vấn tổng hợp](https://firebase.google.com/docs/firestore/query-data/aggregation-queries).

Ngày 08/11/2026: index mới đã được triển khai lên `dalttbdd-b3e19`, đạt trạng thái `READY`; `node tools/verify_dashboard.cjs dalttbdd-b3e19` đã chạy truy vấn tổng hợp thành công. Thao tác này chỉ triển khai indexes, không triển khai luồng Security Rules cấp quyền đang được mô tả ở phần dưới.

Kiểm thử hai tính năng mới trên Android Emulator:

```powershell
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only "firestore,auth" "node tools/android_smoke.cjs --features"
```

Lượt kiểm tra ngày 08/11/2026 đã qua trên Android: số đơn, doanh thu và bộ lọc sản phẩm ngừng bán được kiểm chứng qua Firebase SDK; thu hồi admin chặn việc tải thống kê. Chi tiết các kiểm tra liên quan nằm trong [hướng dẫn lịch hẹn](health-appointments.md#kết-quả-ngày-08112026).

## Người dùng yêu cầu cấp quyền trong ứng dụng

1. Người dùng đã đăng nhập mở **Tài khoản → Yêu cầu quyền quản trị**.
2. Nhập lý do từ 10 đến 500 ký tự và bấm **Gửi yêu cầu**. Mỗi tài khoản có một yêu cầu; khi đang chờ duyệt không thể gửi trùng hoặc thay nội dung.
3. Quản trị viên mở **Trung tâm quản trị → Yêu cầu cấp quyền**, xem người gửi/lý do, rồi **Duyệt cấp quyền** hoặc **Từ chối**. Hộp xác nhận có ô phản hồi tùy chọn.
4. Người gửi thấy kết quả và phản hồi trên màn hình yêu cầu. Sau khi được duyệt, mục **Trung tâm quản trị** xuất hiện ngay trong phiên đăng nhập. Nếu cần, bấm **Cập nhật quyền tài khoản**.
5. Admin có thể **Thu hồi quyền** ở yêu cầu đã duyệt. Người bị từ chối hoặc thu hồi có thể gửi lại lý do để được xem xét lại.

Luồng này dùng Firestore trực tiếp, không yêu cầu triển khai Cloud Functions hay SMTP. Để dùng trên Firebase thật, triển khai bản rules đi kèm trước khi phát hành app:

```powershell
firebase deploy --only firestore:rules --project dalttbdd-b3e19
```

Document yêu cầu lưu UID/email người gửi, lý do, trạng thái, ngày tạo/cập nhật, người duyệt, ngày duyệt và phản hồi. Chỉ người gửi đọc yêu cầu của mình; chỉ admin xem toàn bộ danh sách. Người duyệt không thể đổi thông tin người gửi/lý do, duyệt yêu cầu của chính mình hoặc ghi đè quyết định đã thay đổi. Quyền duyệt và thu hồi được kiểm tra bằng transaction và Security Rules. Ứng dụng theo dõi kết quả từ server; bộ nhớ đệm không tự cấp quyền.

Thu hồi tại yêu cầu chỉ thu hồi quyền được cấp qua yêu cầu đó. Tài khoản được cấp custom claim bằng công cụ chủ dự án vẫn cần thu hồi claim bằng công cụ bên dưới. Root admin đã có custom claim có thể quản lý hệ thống ngay sau khi cập nhật rules.

## Công cụ chủ dự án để cấp hoặc thu hồi quyền

Chỉ người có quyền quản lý Firebase Auth của project được chạy công cụ chủ dự án. Công cụ này dùng để tạo quản trị viên đầu tiên hoặc quản lý custom claim; admin trong ứng dụng có thể duyệt các yêu cầu qua luồng bên trên.

```powershell
firebase login
node tools/manage_admin.cjs dalttbdd-b3e19 grant EMAIL_DA_DANG_KY
node tools/manage_admin.cjs dalttbdd-b3e19 revoke EMAIL_CAN_THU_HOI
```

Công cụ tra đúng email đã đăng ký, giữ nguyên các custom claim khác, không tạo tài khoản hay thay mật khẩu, không xác nhận email thay người dùng và không in OAuth token. Lệnh `revoke` cũng thu hồi yêu cầu đã được duyệt, nếu có; cần quyền quản lý Firestore cho thao tác này. Tài khoản nhận custom claim cần đăng nhập lại hoặc cập nhật quyền trong app. App làm mới token và kiểm tra quyền trên server trước các thao tác quản trị; quyền cấp qua yêu cầu được theo dõi và thu hồi trực tiếp bằng Firestore.

Rules của phiên bản quản trị bằng custom claim trước đây đã được triển khai lên `dalttbdd-b3e19`. Luồng yêu cầu mới cần triển khai bản rules hiện tại:

```powershell
firebase deploy --only firestore:rules --project dalttbdd-b3e19
```

Phần phân quyền và quản trị này dùng Firebase Auth + Firestore trực tiếp, không cần triển khai Cloud Functions mới.

## Kiểm tra

Test `admin_request_test.dart` cần Auth/Firestore Emulator đang chạy ở cổng 9199/8180 theo [hướng dẫn xem demo](demo-preview.md). Test rules sử dụng cổng 8080 riêng để không xóa dữ liệu xem thử.

```powershell
flutter analyze --no-pub
flutter test --no-pub
node --test tools/manage_admin.test.cjs
flutter test integration_test/admin_request_test.dart --no-pub -d emulator-5554 --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=FIRESTORE_EMULATOR_PORT=8180 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9199
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:rules"
firebase emulators:exec --config firebase.integration.json --project demo-pawpals --only firestore,auth "node tools/android_smoke.cjs"
```

Các test xác nhận người dùng không thể tự nâng quyền, tài khoản chưa được cấp quyền không được truy cập quản trị, không sửa giá/tổng tiền trong đơn, không đảo trạng thái đơn kết thúc, hủy hoàn kho đúng một lần và vẫn xử lý được đơn năm loại sản phẩm. Test Android còn kiểm tra custom claim thật của Auth Emulator, sửa sản phẩm khi tồn kho thay đổi và thu hồi quyền.

Đã kiểm tra trên Firebase thật bằng `node tools/verify_admin.cjs dalttbdd-b3e19`: tài khoản thường không tự nâng quyền/sửa sản phẩm, admin đọc được hồ sơ khách nhưng không đọc hồ sơ thú cưng và OTP riêng tư, quyền bị thu hồi bị từ chối sau khi làm mới token. Script dùng hai tài khoản tạm và một sản phẩm ngừng bán tạm rồi tự dọn; báo cáo nằm ở `build/admin-verification.json`.

Kết quả ngày 07/11/2026: 33 test Flutter, 19 test Firestore Rules, 3 test công cụ cấp/thu hồi quyền và 3 test Android đều qua. `flutter analyze --no-pub` không có lỗi/cảnh báo. Rules đã triển khai thành công và kiểm chứng trên project thật; yêu cầu xác nhận email bắt buộc đã được bỏ ngày 11/11/2026, xem hướng dẫn Google hiện tại.

Cập nhật ngày 08/11/2026: 41 test Flutter, 26 test Firestore Rules, 4 test công cụ chủ dự án và 1 test luồng yêu cầu trên Android đều qua; `flutter analyze --no-pub` không có lỗi/cảnh báo. Test Android kiểm tra gửi trùng, từ chối, gửi lại, nhận quyền khi vẫn đăng nhập và bị chặn ngay sau khi thu hồi. Luồng yêu cầu mới đã kiểm tra trên emulator, chưa triển khai rules mới lên Firebase thật.

Tài liệu chính thức: [custom claims và Security Rules](https://firebase.google.com/docs/auth/admin/custom-claims), [transaction và getAfter](https://firebase.google.com/docs/firestore/manage-data/transactions).
