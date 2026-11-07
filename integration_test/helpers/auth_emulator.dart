import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pawpals_app/services/firebase_service.dart';

/// Test-only Admin API, intentionally isolated from the production app.
Future<void> verifyEmulatorEmail() async {
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  const port = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  final service = FirebaseService.instance;
  if (!kDebugMode ||
      host.isEmpty ||
      service.auth.app.options.projectId != 'demo-pawpals') {
    throw StateError('This helper only works with the demo Auth Emulator.');
  }
  final user = service.auth.currentUser!;
  final response = await http
      .post(
        Uri.parse(
          'http://$host:$port/identitytoolkit.googleapis.com/v1/projects/demo-pawpals/accounts:update',
        ),
        headers: {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'localId': user.uid, 'emailVerified': true}),
      )
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw StateError(
      'Auth Emulator verification failed: ${response.statusCode}',
    );
  }
  await service.refreshVerification();
}

Future<void> setEmulatorAdmin(bool enabled) async {
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  const port = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  final service = FirebaseService.instance;
  if (!kDebugMode ||
      host.isEmpty ||
      service.auth.app.options.projectId != 'demo-pawpals') {
    throw StateError('This helper only works with the demo Auth Emulator.');
  }
  final response = await http
      .post(
        Uri.parse(
          'http://$host:$port/identitytoolkit.googleapis.com/v1/projects/demo-pawpals/accounts:update',
        ),
        headers: {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'localId': service.auth.currentUser!.uid,
          'customAttributes': jsonEncode({'admin': enabled}),
        }),
      )
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw StateError('Auth Emulator role update failed.');
  }
  await service.auth.currentUser!.getIdTokenResult(true);
}
