import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wol_agent/agent.dart';

void main() {
  late HttpServer server;
  late List<List<String>> calls;
  final client = HttpClient();

  setUp(() async {
    calls = [];
    server = await startAgent(
      token: 'segredo',
      port: 0,
      address: InternetAddress.loopbackIPv4,
      runCommand: (exe, args) async => calls.add([exe, ...args]),
    );
  });

  tearDown(() => server.close(force: true));
  tearDownAll(() => client.close(force: true));

  Future<(int, String)> send(String method, String path, {String? token}) async {
    final req = await client.open(method, '127.0.0.1', server.port, path);
    if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close();
    return (res.statusCode, await res.transform(utf8.decoder).join());
  }

  test('401 sem token', () async {
    expect((await send('GET', '/status')).$1, 401);
    expect((await send('POST', '/shutdown')).$1, 401);
    expect(calls, isEmpty);
  });

  test('401 com token errado', () async {
    expect((await send('GET', '/status', token: 'errado')).$1, 401);
    expect((await send('POST', '/restart', token: 'segred')).$1, 401);
    expect(calls, isEmpty);
  });

  test('200 em /status com token', () async {
    final (status, body) = await send('GET', '/status', token: 'segredo');
    expect(status, 200);
    expect(jsonDecode(body), {'status': 'online'});
  });

  test('/shutdown e /restart chamam o executor com os argumentos certos', () async {
    expect((await send('POST', '/shutdown', token: 'segredo')).$1, 200);
    expect((await send('POST', '/restart', token: 'segredo')).$1, 200);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(calls, [
      [shutdownExe, '/s', '/t', '0'],
      [shutdownExe, '/r', '/t', '0'],
    ]);
  });

  test('shutdown é chamado pelo caminho absoluto do System32', () {
    expect(shutdownExe.toLowerCase(), endsWith(r'\system32\shutdown.exe'));
    expect(File(shutdownExe).existsSync(), isTrue);
  });

  test('Authorization duplicado dá 401 em vez de pendurar a conexão', () async {
    // Socket cru: o HttpClient juntaria os dois valores numa linha só.
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write('GET /status HTTP/1.1\r\nHost: x\r\nConnection: close\r\n'
        'Authorization: Bearer segredo\r\nAuthorization: Bearer segredo\r\n\r\n');
    final reply = await utf8.decoder.bind(socket).join().timeout(const Duration(seconds: 2));
    expect(reply, startsWith('HTTP/1.1 401'));
  });

  test('5 tokens errados bloqueiam o IP, mesmo com o token certo depois', () async {
    for (var i = 0; i < 5; i++) {
      expect((await send('GET', '/status', token: 'errado')).$1, 401);
    }
    expect((await send('GET', '/status', token: 'segredo')).$1, 429);
    expect((await send('POST', '/shutdown', token: 'segredo')).$1, 429);
    expect(calls, isEmpty);
  });

  test('token certo zera a contagem de erros', () async {
    for (var i = 0; i < 4; i++) {
      await send('GET', '/status', token: 'errado');
    }
    expect((await send('GET', '/status', token: 'segredo')).$1, 200);
    for (var i = 0; i < 4; i++) {
      await send('GET', '/status', token: 'errado');
    }
    expect((await send('GET', '/status', token: 'segredo')).$1, 200);
  });

  test('método/rota desconhecidos dão 404 sem executar nada', () async {
    expect((await send('GET', '/shutdown', token: 'segredo')).$1, 404);
    expect(calls, isEmpty);
  });

  test('strongToken segue a regra do install.ps1', () {
    expect(strongToken.hasMatch('abcdefghijklmnop'), isTrue);
    expect(strongToken.hasMatch('Abc_123-xyz_45678'), isTrue);
    expect(strongToken.hasMatch('abcdefghijklmno'), isFalse);
    expect(strongToken.hasMatch(''), isFalse);
    expect(strongToken.hasMatch('abcdefghijklmnop --port 1'), isFalse);
    expect(strongToken.hasMatch('abcdefghijklmnop"'), isFalse);
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'ab'), isFalse);
    expect(constantTimeEquals('abc', 'abcd'), isFalse);
    expect(constantTimeEquals('abc', ''), isFalse);
  });
}
