import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawpals_app/providers/auth_provider.dart';
import 'package:pawpals_app/views/auth/login_screen.dart';

class _FakeAuth extends AuthProvider {
  bool loading = false;
  final completion = Completer<bool>();
  int googleCalls = 0;
  bool googleResult = false;
  String? googleError;
  @override
  Future<bool> loginWithGoogle() async {
    googleCalls++;
    error = googleError;
    notifyListeners();
    return googleResult;
  }

  @override
  bool get isLoading => loading;
  @override
  Future<bool> login(String email, String password) async {
    loading = true;
    notifyListeners();
    final result = await completion.future;
    loading = false;
    error = 'Email hoặc mật khẩu không đúng.';
    notifyListeners();
    return result;
  }
}

void main() {
  testWidgets(
    'Google sign-in bypasses the email form and cancellation stays quiet',
    (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.ensureVisible(find.text('Tiếp tục với Google'));
      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();
      expect(auth.googleCalls, 1);
      expect(find.text('Email không hợp lệ'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      auth.googleError = 'Không đăng nhập được Google.';
      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();
      expect(find.text('Không đăng nhập được Google.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets(
    'login remains mounted while authentication is pending and displays failure',
    (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
      await tester.ensureVisible(find.text('ĐĂNG NHẬP'));
      await tester.tap(find.text('ĐĂNG NHẬP'));
      await tester.pump();
      expect(find.text('Đang xử lý…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('google-sign-in')),
            )
            .onPressed,
        isNull,
      );
      auth.completion.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
