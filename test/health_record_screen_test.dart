import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pawpals_app/models/health_record_model.dart';
import 'package:pawpals_app/models/pet_model.dart';
import 'package:pawpals_app/providers/pet_provider.dart';
import 'package:pawpals_app/theme/app_theme.dart';
import 'package:pawpals_app/views/pet/pet_detail_screen.dart';
import 'package:pawpals_app/views/pet/health_appointments_section.dart';
import 'package:pawpals_app/services/health_appointments.dart';

final _pet = Pet(
  id: 1,
  name: 'Milo',
  species: 'Dog',
  breed: 'Corgi',
  gender: 'Đực',
  birthDate: '2025-01-01',
  weight: 8,
);

class _Pets extends PetProvider {
  _Pets() : super('ui-appointments');
  HealthRecord? record;
  @override
  List<Pet> get pets => [_pet];
  @override
  List<HealthRecord> getRecordsForPet(int id) =>
      record == null ? [] : [record!];
  @override
  List<HealthAppointment> get appointments => record?.nextDueDate == null
      ? []
      : [HealthAppointment(record: record!, pet: _pet)];
  @override
  Future<void> addHealthRecord(HealthRecord value) async {
    record = HealthRecord.fromMap({...value.toMap(), 'id': value.id ?? 2});
    notifyListeners();
  }

  @override
  Future<void> completeAppointment(int recordId, bool completed) async {
    record = HealthRecord.fromMap({
      ...record!.toMap(),
      'next_due_completed': completed,
    });
    notifyListeners();
  }
}

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'create a same-day appointment, complete and reopen it at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pets = _Pets();
        await tester.pumpWidget(
          ChangeNotifierProvider<PetProvider>.value(
            value: pets,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: PetDetailScreen(pet: _pet),
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nội dung'),
          'Tái khám cho Milo',
        );
        await tester.tap(find.text('Ngày hẹn tiếp theo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Nhắc lịch hẹn'));
        await tester.pumpAndSettle();
        expect(find.text('Nhắc trước 1 ngày và vào ngày hẹn'), findsOneWidget);
        await tester.tap(find.text('Nhắc lịch hẹn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(
          pets.record?.nextDueDate,
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        expect(pets.record?.nextDueReminderEnabled, isFalse);
        expect(find.text('Đến hạn hôm nay'), findsOneWidget);
        await tester.ensureVisible(find.text('Đánh dấu đã thực hiện'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đánh dấu đã thực hiện'));
        await tester.pumpAndSettle();
        expect(pets.record?.nextDueCompleted, isTrue);
        expect(find.text('Đã thực hiện'), findsOneWidget);
        await tester.ensureVisible(find.text('Mở lại lịch hẹn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mở lại lịch hẹn'));
        await tester.pumpAndSettle();
        expect(pets.record?.nextDueCompleted, isFalse);
        expect(find.text('Đến hạn hôm nay'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        pets.dispose();
      },
    );
  }

  testWidgets('home appointments hide completed dates and open the right pet', (
    tester,
  ) async {
    final pets = _Pets()
      ..record = HealthRecord(
        id: 2,
        petId: 1,
        recordType: 'VACCINE',
        title: 'Tiêm nhắc lại',
        administeredDate: '2026-01-01',
        nextDueDate: '2099-12-01',
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<PetProvider>.value(
        value: pets,
        child: MaterialApp(
          home: Scaffold(body: const HealthAppointmentsSection(limit: 3)),
        ),
      ),
    );
    expect(find.text('Milo • Tiêm nhắc lại'), findsOneWidget);
    await tester.tap(find.text('Milo • Tiêm nhắc lại'));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pets.completeAppointment(2, true);
    await tester.pumpAndSettle();
    expect(find.text('Milo • Tiêm nhắc lại'), findsNothing);
    expect(find.textContaining('Chưa có lịch hẹn đang chờ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pets.dispose();
  });

  testWidgets(
    'editing preserves completion until the appointment date changes',
    (tester) async {
      final pets = _Pets()
        ..record = HealthRecord(
          id: 2,
          petId: 1,
          recordType: 'CHECKUP',
          title: 'Tái khám',
          administeredDate: '2026-01-01',
          nextDueDate: '2099-12-01',
          nextDueCompleted: true,
          nextDueReminderTime: '10:30',
        );
      await tester.pumpWidget(
        ChangeNotifierProvider<PetProvider>.value(
          value: pets,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PetDetailScreen(pet: _pet),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(pets.record?.nextDueCompleted, isTrue);
      expect(pets.record?.nextDueReminderTime, '10:30');
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngày hẹn tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(pets.record?.nextDueDate, '2099-12-02');
      expect(pets.record?.nextDueCompleted, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      pets.dispose();
    },
  );
}
