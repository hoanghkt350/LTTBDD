import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pawpals_logo.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _timer;
  bool _sent = false;
  bool _initialSendStarted = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  int _secondsUntil(DateTime? time) {
    if (time == null) return 0;
    return (time.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
      0,
      3600,
    );
  }

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading || _secondsUntil(auth.resendAt) > 0) return;
    final ok = await auth.sendVerificationCode();
    if (mounted && ok) {
      setState(() => _sent = true);
      _code.clear();
    }
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().verifyEmailCode(_code.text);
    // The auth root replaces this screen only after email_verified is refreshed.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cooldown = _secondsUntil(auth.resendAt);
    final expiry = auth.verificationDelivery?.expiresAt;
    final remaining = _secondsUntil(expiry);
    // Registration can emit a pending user before its display-name update ends.
    // Wait until that operation finishes so the initial email is always sent.
    if (!_initialSendStarted && !auth.isLoading) {
      _initialSendStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send();
      });
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: PawPalsLogo(size: 88)),
                    const SizedBox(height: 28),
                    const Text(
                      'Xác nhận email của bạn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _sent
                          ? 'Mã xác nhận đã được gửi đến'
                          : 'Xác nhận email để bảo vệ tài khoản của bạn.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.pendingEmail ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const ValueKey('email-verification-code'),
                      controller: _code,
                      enabled: !auth.isLoading,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mã xác nhận 6 số',
                        hintText: '000000',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Vui lòng nhập đủ 6 chữ số',
                      onFieldSubmitted: (_) {
                        if (!auth.isLoading) _verify();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      expiry == null
                          ? 'Mã có hiệu lực trong 10 phút.'
                          : remaining == 0
                          ? 'Mã đã hết hạn. Vui lòng gửi mã mới.'
                          : 'Mã còn hiệu lực ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 13,
                      ),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          auth.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: auth.isLoading ? null : _verify,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(
                        auth.isLoading ? 'Đang xử lý…' : 'XÁC NHẬN EMAIL',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.isLoading || cooldown > 0 ? null : _send,
                      child: Text(
                        cooldown > 0
                            ? 'Gửi lại mã sau ${cooldown}s'
                            : 'Gửi lại mã xác nhận',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kiểm tra cả thư mục Spam/Thư rác. Chỉ nhập mã trong ứng dụng và không chia sẻ cho người khác.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              try {
                                await auth.logout();
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Chưa đăng xuất được. Vui lòng thử lại.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Dùng tài khoản khác'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
