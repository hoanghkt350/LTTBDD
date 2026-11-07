import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/pawpals_logo.dart';

/// Render immediately while native services start, including on slow devices.
class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.initialize,
    required this.child,
    this.slowAfter = const Duration(seconds: 15),
  });

  final Future<void> Function() initialize;
  final Widget child;
  final Duration slowAfter;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _ready = false;
  bool _loading = false;
  bool _slow = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _slow = false;
      _error = null;
    });
    _timer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      await widget.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      title: 'PawPals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PawPalsLogo(size: 88),
                    const SizedBox(height: 24),
                    const Text(
                      'PawPals',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading) ...[
                      const CircularProgressIndicator(
                        color: AppTheme.secondary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _slow
                            ? 'Khởi tạo đang lâu hơn bình thường'
                            : 'Đang chuẩn bị ứng dụng…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _slow
                            ? 'Thiết bị đang xử lý. Ứng dụng sẽ tự tiếp tục khi sẵn sàng.'
                            : 'Chờ một chút để gặp người bạn nhỏ nhé.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textLight),
                      ),
                    ] else ...[
                      const Text(
                        'Chưa thể khởi tạo ứng dụng',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hãy thử lại. Nếu lỗi tiếp diễn, xem chi tiết bên dưới.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        SelectableText(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 12,
                          ),
                        ),
                    ],
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
