# Thanh toán online qua MoMo

Mã nguồn hỗ trợ COD và ví MoMo (`captureWallet`, tự động thu tiền). **Chưa kích hoạt thanh toán trên Firebase thật**: cần tài khoản đối tác MoMo, cấu hình khóa và triển khai Cloud Functions trên Firebase có billing. Không có khóa mẫu dùng chung, luồng giả lập thành công hoặc khóa bí mật trong Flutter. Kiểm thử tự động dùng máy chủ MoMo mô phỏng; chưa xác minh giao dịch với tài khoản MoMo sandbox/thật.

## Sử dụng

1. Vào giỏ hàng, nhập người nhận, điện thoại, địa chỉ và ưu đãi như trước.
2. Chọn **Ví MoMo → ĐẶT HÀNG • THANH TOÁN MOMO** rồi xác nhận. Máy chủ đọc lại giá và tồn kho, tính ưu đãi/phí giao hàng rồi giữ hàng trong một transaction.
3. Ứng dụng mở đường dẫn HTTPS do MoMo cấp. Thanh toán trên MoMo rồi quay lại PawPals; nút **Mở PawPals** trên trang kết quả có thể đưa về ứng dụng Android.
4. Màn hình theo dõi đơn tự kiểm tra khi ứng dụng quay lại. Có thể bấm **Kiểm tra thanh toán** hoặc vào **Tài khoản → Đơn hàng của tôi → Tiếp tục / kiểm tra thanh toán MoMo**.
5. Đơn chỉ thành **Chờ xác nhận** sau khi máy chủ xác minh kết quả thanh toán. Đóng trình duyệt hoặc mất mạng không làm đơn tự thành công/thất bại.

MoMo hỗ trợ tổng tiền từ 1.000đ đến 50.000.000đ cho luồng này. Mỗi đơn vẫn tối đa 5 loại, mỗi loại 1–99 sản phẩm. Giới hạn tạo 5 phiên MoMo mới/tài khoản/15 phút; thử lại cùng mã đơn không tạo thêm phiên hoặc trừ kho lần nữa.

## Trạng thái, tồn kho và phân quyền

| Kết quả | Đơn hàng | Tồn kho |
| --- | --- | --- |
| Chờ xác nhận trên MoMo/đang xử lý/chưa xác định | Chờ thanh toán | Tiếp tục giữ hàng. |
| MoMo xác nhận thành công, production | Chờ xác nhận, đã thanh toán | Giữ lượng đã trừ để giao hàng. |
| MoMo xác nhận từ chối/hủy/hết hạn | Đã hủy, thanh toán thất bại | Hoàn kho đúng một lần. |
| Sandbox thành công | Thử nghiệm thành công | Hoàn kho; không giao hàng và không tính doanh thu đơn hoàn thành. |
| Tiền đến sau khi đơn đã kết thúc/hoàn kho | Cần đối soát | Không tự giao hàng hay trừ kho lần nữa; cửa hàng kiểm tra/hoàn tiền. |

- Client chỉ đọc đơn thuộc tài khoản của mình. Cả người dùng và admin không được tự sửa trạng thái thanh toán, mã giao dịch hoặc kho phiên thanh toán riêng.
- IPN phải có HMAC-SHA256 đúng, khớp đối tác, số tiền, mã đơn, request ID và nội dung giao dịch. Các thông báo lặp lại và chạy đồng thời không được cộng tiền/hoàn kho nhiều lần.
- Trang redirect chỉ hướng dẫn quay lại ứng dụng, không ghi dữ liệu và không dùng tham số trên URL để xác nhận thanh toán.
- Tác vụ `reconcileMomoPayments` chạy mỗi 5 phút, truy vấn trực tiếp API MoMo cho các phiên chưa xác định để phục hồi khi IPN bị mất. Nút kiểm tra của khách cũng dùng API này và có giới hạn tần suất.
- Không tự hoàn kho chỉ vì hết một khoảng thời gian trên thiết bị. Khi MoMo/API bị lỗi hoặc chưa trả kết quả cuối, vẫn giữ hàng để tránh giao dịch đã trả tiền bị giải phóng kho. Trường hợp kéo dài cần cửa hàng đối soát trên tài khoản đối tác MoMo.
- Admin chỉ chuyển đơn MoMo **đã thanh toán trong production** sang Đang giao/Hoàn thành. Rules cũng bắt buộc điều kiện này. Mục quản trị có trạng thái thanh toán, mã giao dịch và bộ lọc đơn chờ thanh toán/cần đối soát/thử nghiệm.
- Chưa có API hoàn tiền tự động. Khách hủy trước khi trả tiền trên MoMo; đơn đã trả tiền cần cửa hàng đối soát và xử lý hoàn tiền qua tài khoản đối tác. Nút hủy COD không áp dụng cho đơn MoMo.

## Cấu hình và triển khai

1. Chủ dự án chuẩn bị bộ `partnerCode`, `accessKey`, `secretKey` từ tài khoản đối tác MoMo. Dùng bộ sandbox để thử nghiệm; khi được MoMo duyệt production, dùng bộ khóa production riêng. Không gửi khóa qua chat, Git hoặc `--dart-define`.
2. Bật billing/Blaze cho Firebase `dalttbdd-b3e19` trước khi triển khai Cloud Functions. Chạy:

   ```powershell
   firebase login
   npm --prefix functions ci
   powershell -ExecutionPolicy Bypass -File tools/configure_momo.ps1 -Mode sandbox
   ```

   Script nhận hai khóa qua đầu vào ẩn, lưu JSON vào secret `PAWPALS_MOMO_CONFIG`, xóa file tạm trong `finally` và không in khóa. Mặc định luôn là sandbox. Chọn `-Project PROJECT_ID` nếu chuyển dự án. Để thu tiền thật, chạy lại với `-Mode production` và bộ khóa production.

3. Triển khai riêng các functions thanh toán để không phụ thuộc secret SMTP của luồng OTP:

   ```powershell
   firebase deploy --project dalttbdd-b3e19 --only "functions:pawpals-auth:createMomoPayment,functions:pawpals-auth:checkMomoPayment,functions:pawpals-auth:momoIpn,functions:pawpals-auth:momoReturn,functions:pawpals-auth:reconcileMomoPayments,firestore:rules"
   ```

4. Nếu MoMo yêu cầu đăng ký URL trên tài khoản đối tác, dùng đúng:

   - IPN (POST JSON): `https://asia-southeast1-dalttbdd-b3e19.cloudfunctions.net/momoIpn`
   - Redirect: `https://asia-southeast1-dalttbdd-b3e19.cloudfunctions.net/momoReturn`

   Functions tự tạo hai URL theo project đang chạy; không nhận URL hoặc số tiền từ Flutter. Không đổi môi trường/đối tác khi còn phiên chưa kết thúc; cần đối soát các phiên cũ trước khi đổi bộ khóa. Sau khi thay secret, triển khai lại các functions dùng secret.

5. Build/cài bản Android mới:

   ```powershell
   flutter build apk --debug
   ```

6. Kiểm tra trên MoMo sandbox: trả thành công, từ chối, đóng trình duyệt, trở lại ứng dụng, mở lại đơn và IPN gửi lặp. Kiểm tra IPN public trả HTTP 204 sau khi ghi dữ liệu thành công. Theo dõi tác vụ Scheduler và đối soát trong tài khoản MoMo trước khi chuyển production.

## Kiểm thử tự động

```powershell
flutter analyze --no-pub
flutter test --no-pub
npm --prefix functions test
firebase emulators:exec --project demo-pawpals --only firestore "npm --prefix tools run test:payments"
```

Nhóm cuối gồm Firestore Rules và kiểm thử payment service với Firestore Emulator thật. Dữ liệu payment dùng project emulator `demo-pawpals-payments`, tách khỏi `demo-pawpals` của test rules và cổng 8180 của bản xem thử. Chạy ở cổng 8080; không gọi project Firebase thật. API MoMo trong test được mô phỏng, không gọi ví hoặc trừ tiền.

## Kết quả kiểm tra ngày 08/11/2026

- 63 test Flutter qua, gồm màn hình thanh toán ở chiều rộng 320/800, trạng thái từ server, lỗi mở trình duyệt, cảnh báo sandbox và đối soát tiền đến muộn.
- 21 test MoMo phía máy chủ qua; 13 test OTP và 4 test công cụ quản trị hiện có cũng qua.
- 31 test Firestore Rules và 3 test payment service với Firestore Emulator qua. Kiểm chứng giao dịch thực của Firestore, xử lý đồng thời, chặn bán quá tồn và đối soát khi thiếu IPN.
- `flutter analyze --no-pub` không có lỗi/cảnh báo. Script PowerShell cấu hình được kiểm tra cú pháp.
- `flutter build apk --debug --no-pub` thành công; APK ở `build/app/outputs/flutter-apk/app-debug.apk`, dùng Firebase native bình thường, không gắn cấu hình emulator.
- Chưa triển khai payment functions/rules lên Firebase thật; chưa kiểm thử giao dịch qua MoMo sandbox/production vì chưa có bộ khóa đối tác. Hoàn tiền tự động chưa nằm trong phiên bản này.

Tài liệu chính thức: [tạo thanh toán](https://developers.momo.vn/v3/vi/docs/payment/api/wallet/onetime/), [IPN](https://developers.momo.vn/v3/docs/payment/api/result-handling/notification/), [truy vấn kết quả](https://developers.momo.vn/v3/vi/docs/payment/api/payment-api/query/), [mã kết quả](https://developers.momo.vn/v3/vi/docs/payment/api/result-handling/resultcode/).
