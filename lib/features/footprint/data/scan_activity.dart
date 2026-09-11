import 'dart:async';

/// Suspends read-only requests while Android/iOS suspends the UI. A response
/// from before suspension is ignored; the next request reads current progress.
class ScanActivity {
  bool _foreground = true;
  Completer<void> _paused = Completer<void>();
  Completer<void>? _resumed;

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value) {
      _paused = Completer<void>();
      _resumed?.complete();
      _resumed = null;
    } else {
      _resumed = Completer<void>();
      _paused.complete();
    }
  }

  Future<T> read<T>(Future<T> Function() operation) async {
    while (true) {
      if (!_foreground) await _resumed!.future;
      final paused = _paused;
      try {
        return await Future.any([
          operation(),
          paused.future.then<T>((_) => throw const _Suspended()),
        ]);
      } on _Suspended {
        // The server keeps running. Only repeat the GET, never the POST.
      }
    }
  }
}

class _Suspended implements Exception {
  const _Suspended();
}
