import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Plays a sound file on the Linux desktop with the first of the system's
/// players that is there: PulseAudio's (PipeWire serves it too), PipeWire's
/// own, ALSA's, or libcanberra's. A sound given as [bytes] is kept in a file
/// of its own, named by its contents, and played from there.
Future<void> play({String? path, Uint8List? bytes}) async {
  final file = path ?? await _fileOf(bytes);
  if (file == null) return;
  final player = await _player();
  if (player == null) return;
  try {
    await Process.start(player.$1, [
      ...player.$2,
      file,
    ], mode: ProcessStartMode.detached);
  } on ProcessException {
    // No player after all: the notification is shown without its sound.
  }
}

/// The player found, if any: its program and the arguments before the file.
Future<(String, List<String>)?>? _found;

Future<(String, List<String>)?> _player() => _found ??= _find();

Future<(String, List<String>)?> _find() async {
  for (final (program, arguments) in const [
    ('paplay', <String>[]),
    ('pw-play', <String>[]),
    ('aplay', ['-q']),
    ('canberra-gtk-play', ['-f']),
  ]) {
    if (await _onPath(program)) return (program, arguments);
  }
  return null;
}

Future<bool> _onPath(String program) async {
  for (final folder in (Platform.environment['PATH'] ?? '').split(':')) {
    if (folder.isEmpty) continue;
    if (await File(p.join(folder, program)).exists()) return true;
  }
  return false;
}

/// [bytes] in a file of the app's own, its name from what it holds so that
/// the same sound is written once.
Future<String?> _fileOf(Uint8List? bytes) async {
  if (bytes == null) return null;
  try {
    final folder = Directory(
      p.join(Directory.systemTemp.path, 'baocode-sounds'),
    );
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, '${_hash(bytes)}.wav'));
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } on FileSystemException {
    return null;
  }
}

/// FNV-1a, over the bytes: a name for [bytes] that is the same each run.
String _hash(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
