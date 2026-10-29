import 'dart:io';
import 'dart:typed_data';

import 'settings.dart';

/// Magic packet: 6 bytes 0xFF seguidos da MAC repetida 16 vezes (102 bytes).
Uint8List buildMagicPacket(List<int> mac) {
  if (mac.length != 6) throw ArgumentError('MAC deve ter 6 bytes');
  return Uint8List.fromList([...List.filled(6, 0xFF), for (var i = 0; i < 16; i++) ...mac]);
}

const _timeout = Duration(seconds: 2);

class PcController {
  PcController(this.settings);

  final Settings settings;

  Future<void> wake() async {
    final mac = parseMac(settings.mac);
    if (mac == null) throw const FormatException('MAC inválido');
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final sent = socket.send(buildMagicPacket(mac), InternetAddress(settings.broadcast), 9);
      if (sent == 0) throw const SocketException('Falha ao enviar o magic packet');
    } finally {
      socket.close();
    }
  }

  Future<bool> isOnline() async {
    try {
      await _call('GET', '/status');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shutdown() => _call('POST', '/shutdown');

  Future<void> restart() => _call('POST', '/restart');

  Future<void> _call(String method, String path) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.open(method, settings.ip, settings.port, path).timeout(_timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${settings.token}');
      final response = await request.close().timeout(_timeout);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const HttpException('Token recusado pelo agente');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Agente respondeu ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}
