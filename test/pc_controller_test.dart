import 'package:flutter_test/flutter_test.dart';
import 'package:wakeonlan/pc_controller.dart';
import 'package:wakeonlan/settings.dart';

void main() {
  test('magic packet tem 102 bytes: 6x 0xFF + MAC 16x', () {
    final mac = [0xAA, 0xBB, 0xCC, 0x01, 0x02, 0x03];
    final packet = buildMagicPacket(mac);
    expect(packet.length, 102);
    expect(packet.sublist(0, 6), List.filled(6, 0xFF));
    for (var i = 0; i < 16; i++) {
      expect(packet.sublist(6 + i * 6, 12 + i * 6), mac);
    }
  });

  test('parseMac aceita ":" e "-", maiúsculas e minúsculas', () {
    const bytes = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];
    expect(parseMac('AA:BB:CC:DD:EE:FF'), bytes);
    expect(parseMac('aa-bb-cc-dd-ee-ff'), bytes);
    expect(parseMac(' aa:bb:cc:dd:ee:ff '), bytes);
  });

  test('parseMac rejeita formatos inválidos', () {
    for (final s in ['', 'AA:BB:CC:DD:EE', 'AA:BB:CC:DD:EE:FF:00', 'AA:BB-CC:DD:EE:FF', 'GG:BB:CC:DD:EE:FF', 'AABBCCDDEEFF']) {
      expect(parseMac(s), isNull, reason: s);
    }
  });

  test('isValidIpv4', () {
    expect(isValidIpv4('192.168.1.10'), isTrue);
    expect(isValidIpv4('256.1.1.1'), isFalse);
    expect(isValidIpv4('pc.local'), isFalse);
    expect(isValidIpv4(''), isFalse);
  });
}
