import 'dart:async';

import 'package:flutter/material.dart';

import 'pc_controller.dart';
import 'settings.dart';

void main() => runApp(
      MaterialApp(
        title: 'Wake on LAN',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const HomePage(),
      ),
    );

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Settings _settings = const Settings();
  bool? _online;
  DateTime? _wakeSentAt;
  Timer? _timer;

  PcController get _pc => PcController(_settings);

  bool get _waking =>
      _online != true &&
      _wakeSentAt != null &&
      DateTime.now().difference(_wakeSentAt!) < const Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await Settings.load();
    if (!mounted) return;
    setState(() => _settings = settings);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    if (settings.isComplete) {
      _refresh();
    } else {
      _openSettings();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_settings.isComplete) return;
    final online = await _pc.isOnline();
    if (mounted) setState(() => _online = online);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
  }

  Future<void> _wake() async {
    try {
      await _pc.wake();
      setState(() => _wakeSentAt = DateTime.now());
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _power(String label, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label o PC?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(label)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
      setState(() => _wakeSentAt = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comando "$label" enviado')));
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Settings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(initial: _settings)),
    );
    if (result == null) return;
    await result.save();
    setState(() {
      _settings = result;
      _online = null;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (_online) {
      true => ('Online', Colors.green, Icons.check_circle),
      false when _waking => ('Ligando...', Colors.orange, Icons.hourglass_top),
      false => ('Offline', Colors.red, Icons.power_settings_new),
      null => (_settings.isComplete ? 'Verificando...' : 'Configure o PC', Colors.grey, Icons.help_outline),
    };
    final ready = _settings.isComplete;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake on LAN'),
        actions: [
          IconButton(tooltip: 'Atualizar', onPressed: ready ? _refresh : null, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Configurações', onPressed: _openSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 120, color: color, semanticLabel: label),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: ready ? _wake : null,
                icon: const Icon(Icons.power),
                label: const Text('Ligar'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: ready ? () => _power('Desligar', _pc.shutdown) : null,
                icon: const Icon(Icons.power_off),
                label: const Text('Desligar'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: ready ? () => _power('Reiniciar', _pc.restart) : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reiniciar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial});

  final Settings initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final _ip = TextEditingController(text: widget.initial.ip);
  late final _mac = TextEditingController(text: widget.initial.mac);
  late final _broadcast = TextEditingController(text: widget.initial.broadcast);
  late final _port = TextEditingController(text: '${widget.initial.port}');
  late final _token = TextEditingController(text: widget.initial.token);

  @override
  void dispose() {
    for (final c in [_ip, _mac, _broadcast, _port, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _ipValidator(String? v) => isValidIpv4(v ?? '') ? null : 'IPv4 inválido';

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Settings(
        ip: _ip.text.trim(),
        mac: _mac.text.trim(),
        broadcast: _broadcast.text.trim(),
        port: int.parse(_port.text.trim()),
        token: _token.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _ip,
              decoration: const InputDecoration(labelText: 'IP do PC', hintText: '192.168.1.10'),
              keyboardType: TextInputType.number,
              validator: _ipValidator,
            ),
            TextFormField(
              controller: _mac,
              decoration: const InputDecoration(labelText: 'MAC', hintText: 'AA:BB:CC:DD:EE:FF'),
              validator: (v) => parseMac(v ?? '') != null ? null : 'Use AA:BB:CC:DD:EE:FF ou AA-BB-CC-DD-EE-FF',
            ),
            TextFormField(
              controller: _broadcast,
              decoration: const InputDecoration(labelText: 'Endereço de broadcast'),
              keyboardType: TextInputType.number,
              validator: _ipValidator,
            ),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'Porta do agente'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final p = int.tryParse(v?.trim() ?? '');
                return p != null && p > 0 && p <= 65535 ? null : 'Porta inválida';
              },
            ),
            TextFormField(
              controller: _token,
              decoration: const InputDecoration(labelText: 'Token do agente'),
              obscureText: true,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
