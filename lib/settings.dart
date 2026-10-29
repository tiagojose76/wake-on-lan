import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

final _macPattern = RegExp(r'^[0-9A-Fa-f]{2}([:-])[0-9A-Fa-f]{2}(\1[0-9A-Fa-f]{2}){4}$');

/// Aceita AA:BB:CC:DD:EE:FF ou AA-BB-CC-DD-EE-FF; retorna os 6 bytes ou null.
List<int>? parseMac(String input) {
  final s = input.trim();
  if (!_macPattern.hasMatch(s)) return null;
  return s.split(RegExp('[:-]')).map((h) => int.parse(h, radix: 16)).toList();
}

bool isValidIpv4(String input) =>
    InternetAddress.tryParse(input.trim())?.type == InternetAddressType.IPv4;

class Settings {
  const Settings({
    this.ip = '',
    this.mac = '',
    this.broadcast = '255.255.255.255',
    this.port = 8765,
    this.token = '',
  });

  final String ip;
  final String mac;
  final String broadcast;
  final int port;
  final String token;

  bool get isComplete => isValidIpv4(ip) && parseMac(mac) != null && token.isNotEmpty;

  static final _prefs = SharedPreferencesAsync();

  static Future<Settings> load() async => Settings(
        ip: await _prefs.getString('ip') ?? '',
        mac: await _prefs.getString('mac') ?? '',
        broadcast: await _prefs.getString('broadcast') ?? '255.255.255.255',
        port: await _prefs.getInt('port') ?? 8765,
        // shortcut: token em shared_preferences (armazenamento privado do app), trocar por flutter_secure_storage se o app sair da rede de casa
        token: await _prefs.getString('token') ?? '',
      );

  Future<void> save() async {
    await _prefs.setString('ip', ip);
    await _prefs.setString('mac', mac);
    await _prefs.setString('broadcast', broadcast);
    await _prefs.setInt('port', port);
    await _prefs.setString('token', token);
  }
}
