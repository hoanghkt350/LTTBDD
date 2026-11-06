import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController();
  bool _register = false, _hidden = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = _register
        ? await auth.register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
          )
        : await auth.login(_email.text.trim(), _password.text);
    if (!mounted || ok) return; // Auth root owns all navigation.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Không thể đăng nhập.')),
    );
  }

  Future<void> _reset() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập email của bạn trước.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(_email.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Nếu email đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu.'
              : auth.error ?? 'Không gửi được email.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondary.withValues(alpha: .08),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          size: 52,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PawPals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 38,
                        letterSpacing: -1.5,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Một người bạn. Trọn yêu thương.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _register
                          ? 'Tạo tài khoản chăm sóc thú cưng'
                          : 'Chào mừng bạn trở lại',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register
                          ? 'Bắt đầu hành trình cùng người bạn nhỏ.'
                          : 'Người bạn nhỏ đang chờ bạn đấy!',
                      style: const TextStyle(color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 24),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Tên của bạn',
                        ),
                        maxLength: 80,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Vui lòng nhập tên'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Email không hợp lệ',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) >= 6
                          ? null
                          : 'Mật khẩu ít nhất 6 ký tự',
                      onFieldSubmitted: (_) {
                        if (!auth.isLoading) _submit();
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: Text(
                        auth.isLoading
                            ? 'Đang xử lý…'
                            : _register
                            ? 'TẠO TÀI KHOẢN'
                            : 'ĐĂNG NHẬP',
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                    if (!_register)
                      TextButton(
                        onPressed: auth.isLoading ? null : _reset,
                        child: const Text('Quên mật khẩu'),
                      ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          color: AppTheme.secondary,
                          size: 15,
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Chăm sóc tốt hơn, gần nhau hơn.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ),
                      ],
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
