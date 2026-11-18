// Runs `flutter run` for a device and hot-reloads on every saved change.
//
//   dart run tool/flutter_watch.dart <device> [extra flutter run args...]
//
// Flutter only reloads on a keypress, so this starts it in --machine mode and
// sends the `app.restart` command when a file under lib/ or assets/ changes.
// Keys: r = hot reload, R = hot restart, q = quit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _watched = ['lib', 'assets'];
const _debounce = Duration(milliseconds: 250);

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/flutter_watch.dart <device> [flutter args]',
    );
    exit(64);
  }
  final proc = await Process.start('flutter', [
    'run',
    '--machine',
    '-d',
    ...args,
  ], runInShell: true);

  String? appId;
  var nextId = 1;
  var busy = false;
  var pending = false;

  void send(String method, Map<String, Object?> params) {
    proc.stdin.writeln(
      jsonEncode([
        {'id': nextId++, 'method': method, 'params': params},
      ]),
    );
  }

  Future<void> reload({required bool full}) async {
    final id = appId;
    if (id == null) return;
    if (busy) {
      pending = true;
      return;
    }
    busy = true;
    send('app.restart', {
      'appId': id,
      'fullRestart': full,
      'pause': false,
      'reason': 'file-change',
    });
    stdout.writeln(full ? '[watch] hot restart...' : '[watch] hot reload...');
  }

  void handleEvent(Map<String, dynamic> msg) {
    final params = (msg['params'] as Map?)?.cast<String, dynamic>() ?? {};
    switch (msg['event']) {
      case 'app.start':
        appId = params['appId'] as String?;
      case 'app.started':
        stdout.writeln('[watch] running; edit a file under lib/ to reload');
      case 'app.log':
        stdout.write(params['log'] ?? '');
      case 'app.progress':
        if (params['finished'] == true) {
          busy = false;
          if (pending) {
            pending = false;
            unawaited(reload(full: false));
          }
        }
    }
    if (msg['id'] != null) {
      // The restart response is the reliable "done" signal; progress events
      // are not always emitted.
      busy = false;
      if (pending) {
        pending = false;
        unawaited(reload(full: false));
      }
    }
    if (msg['id'] != null && msg['result'] is Map) {
      final code = (msg['result'] as Map)['code'];
      if (code != null && code != 0) {
        stdout.writeln(
          '[watch] reload failed: ${(msg['result'] as Map)['message']}',
        );
      }
    }
  }

  proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    if (!line.startsWith('[{')) {
      stdout.writeln(line);
      return;
    }
    try {
      for (final m in jsonDecode(line) as List) {
        handleEvent((m as Map).cast<String, dynamic>());
      }
    } on FormatException {
      stdout.writeln(line);
    }
  });
  proc.stderr.transform(utf8.decoder).listen(stderr.write);

  Timer? timer;
  for (final dir in _watched) {
    if (!Directory(dir).existsSync()) continue;
    Directory(dir).watch(recursive: true).listen((e) {
      if (e.type == FileSystemEvent.delete && e.path.endsWith('~')) return;
      timer?.cancel();
      timer = Timer(_debounce, () => reload(full: false));
    });
  }

  try {
    stdin.echoMode = false;
    stdin.lineMode = false;
  } on StdinException {
    // not a TTY (piped input): keys are unavailable, watching still works
  }
  stdin.transform(utf8.decoder).listen((keys) {
    for (final k in keys.split('')) {
      if (k == 'r') reload(full: false);
      if (k == 'R') reload(full: true);
      if (k == 'q') {
        final id = appId;
        if (id != null) send('app.stop', {'appId': id});
        proc.stdin.close();
      }
    }
  });

  exit(await proc.exitCode);
}
