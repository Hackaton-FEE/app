import 'package:flutter/foundation.dart';

import '../../auth/data/auth_api_client.dart';
import '../data/unavailable_guard_ai_repository.dart';
import '../domain/guard_ai_repository.dart';

class GuardAiController extends ChangeNotifier {
  GuardAiController(
    this._repository, {
    GuardAiRepository Function()? createRepository,
  }) : _createRepository = createRepository ?? UnavailableGuardAiRepository.new;

  final GuardAiRepository Function() _createRepository;

  GuardAiRepository _repository;
  final Map<int, (GuardAiRepository, GuardAiConversation, String)> _chats = {};
  int _chatId = 0;
  int _nextChatId = 1;

  int get chatId => _chatId;
  Map<int, String> get chats => {
    for (final entry in _chats.entries)
      entry.key: _chatTitle(
        entry.key == _chatId ? _conversation : entry.value.$2,
      ),
    _chatId: _chatTitle(_conversation),
  };

  String _chatTitle(GuardAiConversation conversation) {
    final messages = conversation.messages.where(
      (m) => m.role == GuardAiRole.person,
    );
    if (conversation.isSimulation) return 'Conversación de muestra';
    return messages.isEmpty ? 'Nueva conversación' : messages.first.text;
  }

  Future<void> newChat({GuardAiRepository? repository}) async {
    if (_isSending || _isLoading || _disposed) return;
    _chats[_chatId] = (_repository, _conversation, _draft);
    _chatId = _nextChatId++;
    _repository = repository ?? _createRepository();
    _conversation = GuardAiConversation();
    _draft = '';
    _status = null;
    _loaded = false;
    await load();
  }

  void selectChat(int id) {
    if (_isSending || _isLoading || _disposed || id == _chatId) return;
    final selected = _chats[id];
    if (selected == null) return;
    _chats[_chatId] = (_repository, _conversation, _draft);
    _chatId = id;
    _repository = selected.$1;
    _conversation = selected.$2;
    _draft = selected.$3;
    _loaded = true;
    _error = null;
    _status = null;
    _emit();
  }

  Future<void> deleteChat(int id) async {
    if (_isSending || _isLoading || _disposed) return;
    if (id == _chatId) {
      if (_chats.keys.any((key) => key != id)) {
        selectChat(_chats.keys.firstWhere((key) => key != id));
      } else {
        await newChat();
      }
    }
    _chats.remove(id);
    _emit();
  }

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
    _status = 'Preparando respuesta…';
    _emit();
    try {
      final conversation = await _repository.reply(input);
      if (_disposed) return false;
      _conversation = conversation;
      _draft = '';
      _status = 'Respuesta lista.';
      return true;
    } on GuardAiUnavailable {
      _error = 'GuardAI aún no está conectado. Tu mensaje no se ha enviado.';
      _status = null;
      return false;
    } on AuthApiException {
      _error = 'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';
      _status = null;
      return false;
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

  Future<bool> sendQuickPrompt(String prompt) async {
    if (_isSending || _isLoading || !_loaded || _disposed) return false;
    final savedDraft = _draft;
    setDraft(prompt);
    final succeeded = await sendDraft();
    setDraft(savedDraft);
    return succeeded;
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
