import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/clinic_provider.dart';
import 'services/firebase_service.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/app_startup.dart';
import 'views/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppStartup(
      initialize: () async {
        await FirebaseService.initialize();
        if (!FirebaseService.isFirebaseInitialized) {
          throw StateError(
            FirebaseService.initializationError ??
                'Không thể khởi tạo Firebase.',
          );
        }
      },
      child: const PawPalsApp(),
    ),
  );
}

class PawPalsApp extends StatelessWidget {
  const PawPalsApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AuthProvider()..checkAuthStatus(),
    child: Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final app = MaterialApp(
          key: ValueKey(auth.user?.uid ?? auth.pendingEmail ?? 'signed-out'),
          title: 'PawPals',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: !FirebaseService.isFirebaseInitialized
              ? const _SetupScreen()
              : auth.isCheckingSession
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : auth.isAuthenticated
              ? const MainScreen()
              : const LoginScreen(),
        );
        if (!FirebaseService.isFirebaseInitialized || !auth.isAuthenticated) {
          return app;
        }
        // Session providers must be above Navigator so pushed routes and
        // dialogs share the same account-scoped state.
        return MultiProvider(
          key: ValueKey(auth.user!.uid),
          providers: [
            ChangeNotifierProvider(create: (_) => PetProvider(auth.user!.uid)),
            ChangeNotifierProvider(
              create: (_) => CartProvider(uid: auth.user!.uid)..load(),
            ),
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => ClinicProvider()),
          ],
          child: app,
        );
      },
    ),
  );
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thiết lập PawPals')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Chưa kết nối được Firebase',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thay android/app/google-services.json bằng cấu hình Firebase của bạn, bật Email/Password và triển khai Firestore Rules theo README. Sau đó build lại ứng dụng.',
              ),
              const SizedBox(height: 12),
              SelectableText(
                FirebaseService.initializationError ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
