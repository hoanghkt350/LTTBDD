import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawpals_app/providers/auth_provider.dart';
import 'package:pawpals_app/services/email_verification.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/auth/verify_email_screen.dart';

class _Auth extends AuthProvider {
  bool loading = false;
  int sends = 0;
  String? submitted;
  DateTime? resend;
  @override
  String get pendingEmail => 'friend@gmail.com';
  @override
  bool get isLoading => loading;
  @override
  DateTime? get resendAt => resend;
  @override
  EmailVerificationDelivery? get verificationDelivery => resend == null
      ? null
      : EmailVerificationDelivery(
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          resendAt: resend!,
        );
  @override
  Future<bool> sendVerificationCode() async {
    sends++;
    resend = DateTime.now().add(const Duration(seconds: 60));
    notifyListeners();
    return true;
  }

  @override
  Future<bool> verifyEmailCode(String code) async {
    submitted = code;
    error = 'Mã không đúng. Bạn còn 4 lần thử.';
    notifyListeners();
    return false;
  }

  void finishRegistration() {
    loading = false;
    notifyListeners();
  }
}

Future<void> _mount(WidgetTester tester, _Auth auth) => tester.pumpWidget(
  ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const VerifyEmailScreen(),
    ),
  ),
);

void main() {
  testWidgets('initial mail waits for registration and is sent exactly once', (
    tester,
  ) async {
    final auth = _Auth()..loading = true;
    await _mount(tester, auth);
    await tester.pump();
    expect(auth.sends, 0);
    auth.finishRegistration();
    await tester.pump();
    await tester.pump();
    expect(auth.sends, 1);
    expect(find.text('friend@gmail.com'), findsOneWidget);
    expect(find.text('Mã xác nhận đã được gửi đến'), findsOneWidget);
    final resend = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Gửi lại mã sau 60s'),
    );
    expect(resend.onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(auth.sends, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  for (final width in [320.0, 800.0]) {
    testWidgets(
      'code entry validates length, filters input and shows server errors at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        await _mount(tester, auth);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '12');
        await tester.ensureVisible(find.text('XÁC NHẬN EMAIL'));
        await tester.tap(find.text('XÁC NHẬN EMAIL'));
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng nhập đủ 6 chữ số'), findsOneWidget);
        expect(auth.submitted, isNull);
        await tester.enterText(find.byType(TextFormField), '12a34567');
        await tester.ensureVisible(find.text('XÁC NHẬN EMAIL'));
        await tester.tap(find.text('XÁC NHẬN EMAIL'));
        await tester.pumpAndSettle();
        expect(auth.submitted, '123456');
        expect(find.text('Mã không đúng. Bạn còn 4 lần thử.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      },
    );
  }
}
