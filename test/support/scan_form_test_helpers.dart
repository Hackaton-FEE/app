import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> fillScanContacts(
  WidgetTester tester, {
  String aliases = 'example_alias',
  String phone = '+1 202 555 0123',
}) async {
  for (final entry in {
    'scan-aliases-field': aliases,
    'scan-phone-field': phone,
  }.entries) {
    final field = find.byKey(Key(entry.key));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
    await tester.pumpAndSettle();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
