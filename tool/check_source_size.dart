import 'dart:io';

/// Keep production files cohesive without growing beyond the agreed size.
Future<void> main() async {
  const maxLines = 350;
  final source = Directory.fromUri(Platform.script.resolve('../lib/'));
  final oversized = <String>[];
  var checked = 0;
  var largest = 0;

  await for (final entity in source.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.freezed.dart')) {
      continue;
    }
    final count = (await entity.readAsLines()).length;
    checked++;
    if (count > largest) largest = count;
    if (count > maxLines) {
      final relativePath = entity.path.substring(source.path.length);
      oversized.add('lib/$relativePath: $count líneas (máximo $maxLines)');
    }
  }

  if (oversized.isNotEmpty) {
    oversized.sort();
    stderr.writeln(oversized.join('\n'));
    stderr.writeln('Agrupa y extrae secciones por responsabilidad.');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    '$checked archivos verificados; el mayor tiene $largest líneas.',
  );
}
