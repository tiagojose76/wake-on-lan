import 'dart:convert';
import 'dart:io';

/// Executa um comando do sistema; injetável para os testes não desligarem o PC.
typedef CommandRunner = Future<void> Function(String executable, List<String> args);

/// Mesma regra do `install.ps1` (ValidatePattern): token forte e sem espaço/aspas.
final strongToken = RegExp(r'^[A-Za-z0-9_-]{16,}$');

/// Caminho absoluto: sem isso o Windows procura `shutdown` primeiro na pasta do agent.exe.
final shutdownExe = '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\shutdown.exe';

Future<void> runProcess(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) {
    stderr.writeln('$executable ${args.join(' ')} falhou (${result.exitCode}): ${result.stderr}');
  }
}

Future<HttpServer> startAgent({
  required String token,
  required int port,
  InternetAddress? address,
  CommandRunner runCommand = runProcess,
}) async {
  if (token.isEmpty) throw ArgumentError('token vazio');
  final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
  final failures = <String, _Failures>{};
  server.listen((request) async {
    try {
      await _handle(request, token, runCommand, failures);
    } catch (e) {
      stderr.writeln('erro ao tratar ${request.method} ${request.uri.path}: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {} // resposta já enviada: nada a fazer além do log acima
    }
  });
  return server;
}

const _maxFailures = 5;
const _lockout = Duration(minutes: 1);

class _Failures {
  int count = 0;
  DateTime lockedUntil = DateTime(0);
}

Future<void> _handle(
    HttpRequest request, String token, CommandRunner runCommand, Map<String, _Failures> failures) async {
  final response = request.response;
  final ip = request.connectionInfo?.remoteAddress.address ?? '';
  final now = DateTime.now();
  if (failures[ip]?.lockedUntil.isAfter(now) ?? false) {
    response.statusCode = HttpStatus.tooManyRequests;
    await response.close();
    return;
  }

  final values = request.headers[HttpHeaders.authorizationHeader];
  final auth = values?.length == 1 ? values!.single : '';
  if (!auth.startsWith('Bearer ') || !constantTimeEquals(token, auth.substring(7))) {
    final f = failures.putIfAbsent(ip, _Failures.new);
    if (++f.count >= _maxFailures) {
      f
        ..count = 0
        ..lockedUntil = now.add(_lockout);
    }
    response.statusCode = HttpStatus.unauthorized;
    await response.close();
    return;
  }
  failures.remove(ip);

  final route = '${request.method} ${request.uri.path}';
  if (route == 'GET /status') {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'status': 'online'}));
    await response.close();
    return;
  }

  final args = switch (route) {
    'POST /shutdown' => ['/s', '/t', '0'],
    'POST /restart' => ['/r', '/t', '0'],
    _ => null,
  };
  if (args == null) {
    response.statusCode = HttpStatus.notFound;
    await response.close();
    return;
  }

  // Responde antes de executar para o app receber o 200 antes da rede cair.
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode({'ok': true}));
  await response.close();
  await runCommand(shutdownExe, args);
}

/// Tempo depende só do tamanho do token esperado, não de onde a diferença está.
bool constantTimeEquals(String expected, String actual) {
  final a = utf8.encode(expected);
  final b = utf8.encode(actual);
  var diff = a.length ^ b.length;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ (i < b.length ? b[i] : 0);
  }
  return diff == 0;
}
