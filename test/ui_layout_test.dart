import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawpals_app/models/product_model.dart';
import 'package:pawpals_app/providers/auth_provider.dart';
import 'package:pawpals_app/providers/clinic_provider.dart';
import 'package:pawpals_app/providers/pet_provider.dart';
import 'package:pawpals_app/providers/shop_provider.dart';
import 'package:pawpals_app/services/sample_catalog.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/home/home_screen.dart';
import 'package:pawpals_app/widgets/care_widgets.dart';

class _Shop extends ShopProvider {
  @override
  List<Product> get featured => sampleProducts.take(4).toList();
}

void main() {
  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('home layout and shortcuts work at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? destination;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => PetProvider('ui-test')),
            ChangeNotifierProvider<ShopProvider>(create: (_) => _Shop()),
            ChangeNotifierProvider(create: (_) => ClinicProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(onTabChange: (index) => destination = index),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Khám phá cửa hàng'));
      expect(destination, 2);
      await tester.scrollUntilVisible(
        find.text('Phòng khám'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phòng khám'));
      expect(destination, 3);
      await tester.scrollUntilVisible(
        find.text(sampleProducts.first.name),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCard), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
