import 'dart:io';

import 'package:wol_agent/agent.dart';

/// Uso: `agent --token <token> [--port 8765]`
/// ou variáveis de ambiente WOL_AGENT_TOKEN / WOL_AGENT_PORT.
Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final token = arg('token') ?? Platform.environment['WOL_AGENT_TOKEN'] ?? '';
  final port = int.tryParse(arg('port') ?? Platform.environment['WOL_AGENT_PORT'] ?? '8765');
  if (!strongToken.hasMatch(token)) {
    stderr.writeln('Token obrigatório (16+ caracteres A-Z a-z 0-9 _ -): use --token <token> ou WOL_AGENT_TOKEN.');
    exit(64);
  }
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('Porta inválida.');
    exit(64);
  }

  final server = await startAgent(token: token, port: port);
  stdout.writeln('wol_agent ouvindo na porta ${server.port}');
}
