// Regenerate all app icons: flutter test tools/render_brand_icons.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/widgets/pawpals_logo.dart';

void main() {
  testWidgets('export the shared PawPals vector mark as platform icons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const ColoredBox(
              color: Color(0xFFEAF2E9),
              child: PawPalsLogo(size: 1024),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      Future<Uint8List> png(int size) async {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: size,
          targetHeight: size,
        );
        final frame = await codec.getNextFrame();
        final data = (await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        frame.image.dispose();
        codec.dispose();
        return data;
      }

      final outputs = <String, int>{
        'assets/branding/pawpals-logo.png': 1024,
        for (final item in {
          'mdpi': 48,
          'hdpi': 72,
          'xhdpi': 96,
          'xxhdpi': 144,
          'xxxhdpi': 192,
        }.entries)
          'android/app/src/main/res/mipmap-${item.key}/ic_launcher.png':
              item.value,
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
        for (final size in [16, 32, 64, 128, 256, 512, 1024])
          'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png':
              size,
      };
      final iosDirectory = Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      );
      for (final file in iosDirectory.listSync().whereType<File>()) {
        if (!file.path.endsWith('.png')) continue;
        final filename = file.uri.pathSegments.last;
        final match = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png')
            .firstMatch(filename);
        if (match != null) {
          outputs[file.path] = (double.parse(match[1]!) * int.parse(match[2]!))
              .round();
        }
      }
      for (final output in outputs.entries) {
        final file = File(output.key);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(await png(output.value));
      }
      // Windows ICO with a 256px PNG entry (supported since Windows Vista).
      final icon = await png(256);
      final header = ByteData(22)
        ..setUint16(2, 1, Endian.little)
        ..setUint16(4, 1, Endian.little)
        ..setUint16(10, 1, Endian.little)
        ..setUint16(12, 32, Endian.little)
        ..setUint32(14, icon.length, Endian.little)
        ..setUint32(18, 22, Endian.little);
      await File('windows/runner/resources/app_icon.ico')
          .writeAsBytes([...header.buffer.asUint8List(), ...icon]);
    });
  });
}
