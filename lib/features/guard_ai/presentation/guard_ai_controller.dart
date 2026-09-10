import 'package:flutter/foundation.dart';

import '../domain/guard_ai_repository.dart';

class GuardAiController extends ChangeNotifier {
  GuardAiController(this._repository);

  final GuardAiRepository _repository;
  GuardAiConversation _conversation = GuardAiConversation();
  String _draft = '';
  String? _error;
  String? _status;
  bool _loaded = false;
  bool _isLoading = false;
  bool _isSending = false;
  bool _disposed = false;

  GuardAiConversation get conversation => _conversation;
  String get draft => _draft;
  String? get error => _error;
  String? get status => _status;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isReady => _loaded;

  void setDraft(String value) {
    if (_disposed || _isSending || _draft == value) return;
    _draft = value;
    _emit();
  }

  Future<void> load() async {
    if (_disposed || _loaded || _isLoading) return;
    _isLoading = true;
    _error = null;
    _emit();
    try {
      final conversation = await _repository.loadConversation();
      if (_disposed) return;
      _conversation = conversation;
      _loaded = true;
    } catch (_) {
      _error = 'No pudimos abrir el chat. Inténtalo de nuevo.';
    } finally {
      _isLoading = false;
      _emit();
    }
  }

  Future<bool> sendDraft() async {
    if (_disposed || !_loaded || _isLoading || _isSending) return false;
    late final GuardAiInput input;
    try {
      input = GuardAiInput(_draft);
    } on FormatException {
      _error = _draft.trim().isEmpty
          ? 'Escribe un mensaje o elige una sugerencia para continuar.'
          : 'Acorta el mensaje a ${GuardAiInput.maxLength} caracteres o menos.';
      _status = null;
      _emit();
      return false;
    }
    _isSending = true;
    _error = null;
    _status = 'Analizando consulta…';
    _emit();
    try {
      final conversation = await _repository.reply(input);
      if (_disposed) return false;
      _conversation = conversation;
      _draft = '';
      _status = 'Respuesta lista.';
      return true;
    } catch (_) {
      _error =
          'No pudimos preparar la respuesta. Tu mensaje sigue aquí; '
          'puedes volver a intentarlo.';
      _status = null;
      return false;
    } finally {
      _isSending = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
