import 'dart:async';

import 'package:fee_app/features/cases/data/case_storage.dart';

/// A test double only; a new repository can share it to simulate a restart.
class FakeCaseStorage implements CaseStorage {
  final Map<String, String> records = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  int writes = 0;
  int deletes = 0;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;

  @override
  Future<Map<String, String>> readAll() async {
    if (failRead) throw StateError('private-storage-detail');
    return Map.of(records);
  }

  @override
  Future<void> write(String id, String value) async {
    writes++;
    writeStarted?.complete();
    await writeGate?.future;
    if (failWrite) throw StateError('private-storage-detail');
    records[id] = value;
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    if (failDelete) throw StateError('private-storage-detail');
    records.remove(id);
  }
}
