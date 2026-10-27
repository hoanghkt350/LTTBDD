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
import 'views/main_screen.dart';

void main() async {
  // Đảm bảo Flutter Binding đã được khởi tạo theo Bài 6 (mục 6.5.2) giáo trình
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Google Firebase Core
  await FirebaseService.initialize();

  runApp(const PawPalsApp());
}

class PawPalsApp extends StatelessWidget {
  const PawPalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo các Provider quản lý trạng thái theo Bài 7 giáo trình
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => PetProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'PawPals - Chăm Sóc & Mua Sắm Thú Cưng',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: auth.isLoading
                ? const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
                    ),
                  )
                : (auth.isAuthenticated ? const MainScreen() : const LoginScreen()),
          );
        },
      ),
    );
  }
}
