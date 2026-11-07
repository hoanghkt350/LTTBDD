import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpals_app/views/auth/app_startup.dart';

const ready = MaterialApp(home: Scaffold(body: Text('Ứng dụng sẵn sàng')));

void main() {
  testWidgets('shows progress and accepts native success after 15 seconds', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          calls++;
          return completion.future;
        },
        child: ready,
      ),
    );
    expect(find.text('Đang chuẩn bị ứng dụng…'), findsOneWidget);
    expect(find.text('Ứng dụng sẵn sàng'), findsNothing);
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('Khởi tạo đang lâu hơn bình thường'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(calls, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng sẵn sàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual initialization failure can be retried', (tester) async {
    var calls = 0;
    final retry = Completer<void>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          if (++calls == 1) throw StateError('Lỗi khởi tạo thử nghiệm');
          await retry.future;
        },
        child: ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Lỗi khởi tạo thử nghiệm'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Thử lại'), findsNothing);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng sẵn sàng'), findsOneWidget);
  });

  testWidgets('completion after disposal does not update a disposed widget', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(
      AppStartup(initialize: () => completion.future, child: ready),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });
}
