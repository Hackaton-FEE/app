import 'dart:convert';

import '../domain/scan_history_entry.dart';
import '../domain/scan_history_repository.dart';
import 'scan_history_storage.dart';

class LocalScanHistoryRepository implements ScanHistoryRepository {
  LocalScanHistoryRepository({
    required this.storage,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ScanHistoryStorage storage;
  final DateTime Function() _clock;
  Future<void>? _pending;
  static const maxRecordBytes = 32 * 1024;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending == null
        ? operation()
        : _pending!.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  ScanHistoryEntry _decode(String key, String value) {
    try {
      if (utf8.encode(value).length > maxRecordBytes) {
        throw const FormatException();
      }
      final entry = ScanHistoryEntry.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      if (entry.id != key ||
          key.isEmpty ||
          entry.targetIdentity.trim().isEmpty) {
        throw const FormatException();
      }
      return entry;
    } catch (_) {
      throw const FormatException(
        'El historial contiene un registro inválido.',
      );
    }
  }

  Future<List<ScanHistoryEntry>> _read() async {
    final records = await storage.readAll();
    // Validate the entire collection before pruning or changing any record.
    return [
      for (final record in records.entries) _decode(record.key, record.value),
    ];
  }

  Future<List<ScanHistoryEntry>> _prune(List<ScanHistoryEntry> entries) async {
    final now = _clock().toUtc();
    final current = <ScanHistoryEntry>[];
    for (final entry in entries) {
      if (entry.isExpired(now)) {
        await storage.delete(entry.id);
      } else {
        current.add(entry);
      }
    }
    return current;
  }

  @override
  Future<List<ScanHistoryEntry>> loadHistory() => _enqueue(() async {
    final entries = await _prune(await _read());
    entries.sort(ScanHistoryEntry.compareByRecency);
    return List.unmodifiable(entries);
  });

  @override
  Future<void> saveScan(ScanHistoryEntry entry) => _enqueue(() async {
    final record = jsonEncode(entry.toJson());
    _decode(entry.id, record);
    await _prune(await _read());
    await storage.write(entry.id, record);
  });

  @override
  Future<void> deleteScan(String id) => _enqueue(() async {
    await _read();
    await storage.delete(id);
  });

  @override
  Future<void> pruneExpired() => _enqueue(() async {
    await _prune(await _read());
  });

  @override
  Future<void> clearAll() => _enqueue(() async {
    // Only an explicit clear-all action can delete an unreadable record.
    final records = await storage.readAll();
    for (final key in records.keys) {
      await storage.delete(key);
    }
  });
}
