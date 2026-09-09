import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/case_input.dart';
import '../domain/case_repository.dart';
import '../domain/privacy_case.dart';
import 'case_storage.dart';

/// Storage is the source of truth. Compose one instance per app session.
///
/// Operations are queued so reads cannot overtake writes. No success is returned
/// before storage confirms the operation, and errors never trigger a reset.
class LocalCaseRepository implements CaseRepository {
  LocalCaseRepository({
    required this._storage,
    DateTime Function()? clock,
    String Function()? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? const Uuid().v4;

  final CaseStorage _storage;
  final DateTime Function() _clock;
  final String Function() _idFactory;
  Future<void> _pending = Future<void>.value();
  static const _maxRecordBytes = 32 * 1024;

  static final _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static const _recordFields = {
    'schemaVersion',
    'id',
    'title',
    'sourceUrl',
    'category',
    'notes',
    'status',
    'createdAt',
    'updatedAt',
  };

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    // A rejected operation must not poison later operations or retain its error.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _storageCall<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      throw const CaseRepositoryException(
        CaseRepositoryExceptionReason.storageUnavailable,
      );
    }
  }

  Future<List<PrivacyCase>> _readCases() async {
    final records = await _storageCall(_storage.readAll);
    // Validate every record before a mutation, including unrelated cases.
    // Only a public collection read needs to sort and freeze this private list.
    return records.entries
        .map((entry) => _decode(entry.key, entry.value))
        .toList();
  }

  @override
  Future<List<PrivacyCase>> loadCases() => _enqueue(() async {
    final cases = await _readCases();
    cases.sort(PrivacyCase.compareByRecency);
    return List.unmodifiable(cases);
  });

  @override
  Future<PrivacyCase> createCase(CaseInput input) => _enqueue(() async {
    final cases = await _readCases();
    final id = _idFactory();
    if (!_idPattern.hasMatch(id) || cases.any((item) => item.id == id)) {
      throw const CaseRepositoryException(
        CaseRepositoryExceptionReason.storageUnavailable,
      );
    }
    final now = _clock().toUtc();
    final value = PrivacyCase(
      id: id,
      title: input.title,
      sourceUrl: input.sourceUrl,
      category: input.category,
      notes: input.notes,
      status: CaseStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    await _store(value);
    return value;
  });

  @override
  Future<PrivacyCase> updateCase(String id, CaseInput input) =>
      _enqueue(() async {
        final current = _find(await _readCases(), id);
        final value = PrivacyCase(
          id: current.id,
          title: input.title,
          sourceUrl: input.sourceUrl,
          category: input.category,
          notes: input.notes,
          status: current.status,
          createdAt: current.createdAt,
          updatedAt: _nextUpdate(current),
        );
        await _store(value);
        return value;
      });

  @override
  Future<PrivacyCase> setArchived(String id, bool archived) =>
      _enqueue(() async {
        final current = _find(await _readCases(), id);
        final status = archived ? CaseStatus.archived : CaseStatus.draft;
        if (current.status == status) return current;
        final value = PrivacyCase(
          id: current.id,
          title: current.title,
          sourceUrl: current.sourceUrl,
          category: current.category,
          notes: current.notes,
          status: status,
          createdAt: current.createdAt,
          updatedAt: _nextUpdate(current),
        );
        await _store(value);
        return value;
      });

  @override
  Future<void> deleteCase(String id) => _enqueue(() async {
    _find(await _readCases(), id);
    await _storageCall(() => _storage.delete(id));
  });

  DateTime _nextUpdate(PrivacyCase current) {
    final now = _clock().toUtc();
    // Device-clock rollback must not create a record that fails its own schema.
    return now.isBefore(current.updatedAt) ? current.updatedAt : now;
  }

  PrivacyCase _find(List<PrivacyCase> cases, String id) {
    for (final value in cases) {
      if (value.id == id) return value;
    }
    throw const CaseRepositoryException(CaseRepositoryExceptionReason.notFound);
  }

  Future<void> _store(PrivacyCase value) async {
    final record = jsonEncode({
      'schemaVersion': 1,
      'id': value.id,
      'title': value.title,
      'sourceUrl': value.sourceUrl.toString(),
      'category': value.category.name,
      'notes': value.notes,
      'status': value.status.name,
      'createdAt': value.createdAt.toIso8601String(),
      'updatedAt': value.updatedAt.toIso8601String(),
    });
    // Validated input is bounded to 24 KiB; fixed record metadata fits in the
    // remaining 8 KiB. Keep this guard symmetric with reads for future changes.
    if (utf8.encode(record).length > _maxRecordBytes) {
      throw const CaseRepositoryException(
        CaseRepositoryExceptionReason.invalidStoredData,
      );
    }
    await _storageCall(() => _storage.write(value.id, record));
  }

  PrivacyCase _decode(String storageId, String record) {
    try {
      if (utf8.encode(record).length > _maxRecordBytes ||
          !_idPattern.hasMatch(storageId)) {
        throw const FormatException();
      }
      final json = jsonDecode(record);
      if (json is! Map<String, dynamic> ||
          json.length != _recordFields.length ||
          !json.keys.every(_recordFields.contains) ||
          json['schemaVersion'] != 1 ||
          json['schemaVersion'] is! int ||
          json['id'] != storageId) {
        throw const FormatException();
      }
      final category = CaseCategory.values.byName(json['category'] as String);
      final status = CaseStatus.values.byName(json['status'] as String);
      final input = CaseInput(
        title: json['title'] as String,
        sourceUrl: json['sourceUrl'] as String,
        category: category,
        notes: json['notes'] as String,
      );
      if (input.title != json['title'] ||
          input.notes != json['notes'] ||
          input.sourceUrl.toString() != json['sourceUrl']) {
        throw const FormatException();
      }
      final createdAt = _decodeDate(json['createdAt']);
      final updatedAt = _decodeDate(json['updatedAt']);
      if (updatedAt.isBefore(createdAt)) throw const FormatException();
      return PrivacyCase(
        id: storageId,
        title: input.title,
        sourceUrl: input.sourceUrl,
        category: category,
        notes: input.notes,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (_) {
      throw const CaseRepositoryException(
        CaseRepositoryExceptionReason.invalidStoredData,
      );
    }
  }

  DateTime _decodeDate(Object? value) {
    if (value is! String) throw const FormatException();
    final parsed = DateTime.parse(value);
    if (!parsed.isUtc || parsed.toIso8601String() != value) {
      throw const FormatException();
    }
    return parsed;
  }
}
