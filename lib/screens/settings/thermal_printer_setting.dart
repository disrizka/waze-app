// thermal_printer_settings_screen.dart
// Perbaikan WRITE: kirim List<int> + chunked agar sesuai plugin & stabil.

import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:wa_blast/constants/app_colors.dart';

class ThermalPrinterSettingsScreen extends StatefulWidget {
  const ThermalPrinterSettingsScreen({super.key});

  @override
  State<ThermalPrinterSettingsScreen> createState() =>
      _ThermalPrinterSettingsScreenState();
}

class _ThermalPrinterSettingsScreenState
    extends State<ThermalPrinterSettingsScreen> {
  // ===== UI controllers
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  final _pickedCtrl = TextEditingController();

  // ===== State
  String _type = 'bluetooth'; // 'bluetooth' | 'network'
  int _paper = 58; // 58 | 80

  String? _btId; // Android: MAC, iOS BLE: UUID
  String? _btName; // Nama perangkat

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  bool get _isAndroid => Platform.isAndroid;
  bool get _isIOS => Platform.isIOS;

  // ===== Android MAC regex
  final _macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  // ===== Native channel (Android) untuk ambil bonded devices (nama + MAC)
  static const MethodChannel _btChannel = MethodChannel('bt/paired');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pickedCtrl.dispose();
    super.dispose();
  }

  // ================= Permissions =================
  Future<void> _ensureBluetoothPermission() async {
    if (_isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isDenied) throw 'Bluetooth permission denied';
    } else {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse, // beberapa device lama masih minta
      ].request();

      if (statuses[Permission.bluetoothConnect]?.isDenied == true) {
        throw 'Bluetooth Connect permission is required';
      }
    }
  }

  // ================= Load/Save prefs =================
  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _type = sp.getString('printer.type') ?? 'bluetooth';
      _btId = sp.getString('printer.bt.id');
      _btName = sp.getString('printer.bt.name');
      _pickedCtrl.text = _formatPickedDisplay(_btName, _btId);

      _ipCtrl.text = sp.getString('printer.ip') ?? '';
      _portCtrl.text = (sp.getInt('printer.port') ?? 9100).toString();
      _paper = sp.getInt('printer.paper') ?? 58;

      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('printer.type', _type);
    await sp.setInt('printer.paper', _paper);
    await sp.setString('printer.ip', _ipCtrl.text.trim());
    await sp.setInt(
      'printer.port',
      int.tryParse(_portCtrl.text.trim()) ?? 9100,
    );
    if (_btId?.isNotEmpty == true) await sp.setString('printer.bt.id', _btId!);
    if (_btName?.isNotEmpty == true)
      await sp.setString('printer.bt.name', _btName!);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Printer settings saved');
  }

  // ================= Helpers =================
  String _formatPickedDisplay(String? name, String? id) {
    final n = (name ?? '').trim();
    final i = (id ?? '').trim();
    if (n.isEmpty && i.isEmpty) return '';
    if (n.isNotEmpty && i.isNotEmpty) {
      final short = i.length > 10 ? '${i.substring(0, 10)}…' : i;
      return '$n ($short)';
    }
    return n.isNotEmpty ? n : i;
  }

  String _extractName(dynamic d) {
    try {
      final n = (d as dynamic).name;
      if (n != null) return n.toString();
    } catch (_) {}
    try {
      final n = (d as Map)['name'];
      if (n != null) return n.toString();
    } catch (_) {}
    return '';
  }

  String _extractIdentifier(dynamic d) {
    try {
      final m = (d as dynamic).macAddress;
      if (m != null && m.toString().isNotEmpty) return m.toString();
    } catch (_) {}
    try {
      final a = (d as dynamic).address;
      if (a != null && a.toString().isNotEmpty) return a.toString();
    } catch (_) {}
    try {
      final map = d as Map;
      for (final k in [
        'macAddress',
        'address',
        'deviceAddress',
        'btAddress',
        'MAC',
        'MacAddress',
        'mac',
        'id',
        'uuid',
      ]) {
        if (map.containsKey(k) && (map[k]?.toString().isNotEmpty ?? false)) {
          return map[k].toString();
        }
      }
    } catch (_) {}
    return '';
  }

  // ================= Native bonded list (Android) =================
  Future<List<Map<String, String>>> _getBondedFromNative() async {
    if (!_isAndroid) return [];
    try {
      final res = await _btChannel.invokeMethod('getBonded');
      final out = <Map<String, String>>[];
      if (res is List) {
        for (final e in res) {
          if (e is Map) {
            final name = (e['name'] ?? '').toString();
            final addr = (e['address'] ?? '').toString(); // MAC
            out.add({'name': name, 'id': addr});
          }
        }
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('[BT] getBonded error: $e');
      return [];
    }
  }

  // ================= Scan & Pick =================
  Future<void> _scanAndPickBluetooth() async {
    try {
      await _ensureBluetoothPermission();
      final btOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (btOn != true) {
        _snack('Please turn on Bluetooth first');
        return;
      }

      // 1) plugin
      final pluginList = <Map<String, String>>[];
      try {
        final paired = await PrintBluetoothThermal.pairedBluetooths;
        if (paired != null) {
          for (final d in List<dynamic>.from(paired)) {
            final name = _extractName(d);
            final id = _extractIdentifier(d); // bisa kosong
            pluginList.add({'name': name, 'id': id});
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('pairedBluetooths error: $e');
      }

      // 2) native
      final nativeList = await _getBondedFromNative();

      // 3) merge (utamakan yang punya MAC dari native)
      final merged = <String, Map<String, String>>{};
      for (final it in pluginList) {
        final key = (it['name'] ?? '').isNotEmpty
            ? it['name']!
            : (it['id'] ?? '');
        if (key.isEmpty) continue;
        merged[key] = {'name': it['name'] ?? '', 'id': it['id'] ?? ''};
      }
      for (final it in nativeList) {
        final key = (it['name'] ?? '').isNotEmpty
            ? it['name']!
            : (it['id'] ?? '');
        if (key.isEmpty) continue;
        final old = merged[key];
        if (old == null || (old['id'] ?? '').isEmpty) {
          merged[key] = {'name': it['name'] ?? '', 'id': it['id'] ?? ''};
        }
      }

      final list = merged.values.toList();
      if (list.isEmpty) {
        _snack('No paired Bluetooth devices found');
        return;
      }

      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, String>>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final it = list[i];
              final name = it['name'] ?? '';
              final id = it['id'] ?? '';
              return ListTile(
                leading: const Icon(LucideIcons.printer),
                title: Text(name.isEmpty ? 'Unknown' : name),
                subtitle: Text(id.isEmpty ? '(no identifier)' : id),
                onTap: () => Navigator.pop(ctx, it),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: list.length,
          ),
        ),
      );

      if (picked != null) {
        setState(() {
          _btName = picked['name'] ?? '';
          _btId = picked['id'] ?? '';
          _pickedCtrl.text = _formatPickedDisplay(_btName, _btId);
        });
      }
    } catch (e) {
      _snack('Scan failed: $e');
    }
  }

  // ================= ESC/POS builder =================
  Future<Uint8List> _buildTestBytes() async {
    final profile = await esc.CapabilityProfile.load();
    final gen = esc.Generator(
      _paper == 80 ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
      profile,
    );
    final b = <int>[];
    b.addAll(
      gen.text(
        'TEST PRINT',
        styles: const esc.PosStyles(
          align: esc.PosAlign.center,
          bold: true,
          height: esc.PosTextSize.size2,
          width: esc.PosTextSize.size2,
        ),
      ),
    );
    b.addAll(gen.hr());
    b.addAll(gen.text('Hello from WaveUp!'));
    b.addAll(gen.text('Paper: $_paper mm'));
    b.addAll(gen.text('Mode: ${_type.toUpperCase()}'));
    b.addAll(gen.feed(2));
    b.addAll(gen.cut());
    return Uint8List.fromList(b);
  }

  // ================= WRITE helper (fix ClassCastException) =================
  Future<void> _writeBluetoothBytesChunked(Uint8List data) async {
    // plugin butuh List<int>, bukan Uint8List
    final payload = data.toList();

    // ukuran chunk aman: iOS BLE biasanya 20 bytes, Android SPP bisa besar
    final chunkSize = _isIOS ? 20 : 512;
    for (int offset = 0; offset < payload.length; offset += chunkSize) {
      final end = (offset + chunkSize < payload.length)
          ? offset + chunkSize
          : payload.length;
      final part = payload.sublist(offset, end);

      final ok = await PrintBluetoothThermal.writeBytes(part);
      if (kDebugMode) debugPrint('[BT] write part ${offset}..${end} => $ok');
      if (ok != true) throw 'Write failed';
      // jeda kecil antar chunk
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  // ================= Test Print =================
  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      if (_type == 'network') {
        // RAW 9100
        final ip = _ipCtrl.text.trim();
        if (ip.isEmpty) throw 'IP Address empty';
        final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
        final data = await _buildTestBytes();
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 4),
        );
        socket.add(data);
        await socket.flush();
        await socket.close();
      } else {
        // Bluetooth
        await _ensureBluetoothPermission();

        final id = (_btId ?? '').trim();
        final name = (_btName ?? '').trim();
        if (kDebugMode) {
          debugPrint(
            '[BT] prepared name="$name" id="$id" (android=$_isAndroid)',
          );
        }

        // Android HARUS MAC valid
        if (_isAndroid && !_macRegex.hasMatch(id)) {
          _snack(
            'Failed to resolve MAC. Pair the printer in Android Bluetooth Settings, then try again.',
          );
          return;
        }
        if (id.isEmpty && name.isEmpty) {
          _snack('No device selected. Please Scan & Pick first.');
          return;
        }

        // Putus koneksi lama (best-effort)
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}

        // Connect
        final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: id, // iOS: UUID; Android: MAC
        );
        if (kDebugMode) debugPrint('[BT] connect("$id") => $connected');

        if (connected != true) {
          throw _isIOS
              ? 'Unable to connect (iOS supports BLE only). Ensure printer is BLE and paired.'
              : 'Unable to connect printer. Make sure it is paired and MAC is correct.';
        }

        final ok = await PrintBluetoothThermal.connectionStatus;
        if (ok != true) throw 'Bluetooth not connected';

        // Delay kecil sebelum kirim pertama (beberapa chipset perlu)
        await Future.delayed(const Duration(milliseconds: 150));

        final data = await _buildTestBytes();

        // TULIS: gunakan helper chunked (List<int>)
        try {
          await _writeBluetoothBytesChunked(data);
        } catch (_) {
          // Retry sekali (beberapa device perlu "pemanasan")
          await Future.delayed(const Duration(milliseconds: 200));
          await _writeBluetoothBytesChunked(data);
        }
      }

      _snack('Test print sent');
    } catch (e) {
      _snack('Test failed: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final disabled = _saving || _testing || _loading;
    final isBt = _type == 'bluetooth';
    final canTest =
        !disabled &&
        (!isBt ||
            (_isAndroid ? _macRegex.hasMatch((_btId ?? '').trim()) : true));

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    );

    final segments = const <ButtonSegment<String>>[
      ButtonSegment(
        value: 'bluetooth',
        label: Text('Bluetooth'),
        icon: Icon(LucideIcons.bluetooth),
      ),
      ButtonSegment(
        value: 'network',
        label: Text('Network'),
        icon: Icon(LucideIcons.network),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thermal Printer',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canTest ? _testPrint : null,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.printer),
                label: const Text('Test Print'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: disabled ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.save, color: Colors.white),
                label: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_isIOS)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'iOS: Many ESC/POS Bluetooth printers work only if they are BLE. Prefer Network (RAW 9100) when possible.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                  ),

                if (_isAndroid &&
                    isBt &&
                    !_macRegex.hasMatch((_btId ?? '').trim()))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Android requires a valid Bluetooth MAC to connect. '
                      'Tap "Scan & Pick" (paired devices) and we will resolve MAC automatically.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),

                SegmentedButton<String>(
                  segments: segments,
                  selected: {_type},
                  onSelectionChanged: disabled
                      ? null
                      : (s) => setState(() => _type = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),

                AnimatedCrossFade(
                  crossFadeState: isBt
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 200),
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _pickedCtrl,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Selected Device',
                          prefixIcon: const Icon(LucideIcons.bluetooth),
                          border: border,
                          disabledBorder: border,
                          helperText:
                              'Tap "Scan & Pick" to select a paired Bluetooth printer.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: disabled ? null : _scanAndPickBluetooth,
                        icon: const Icon(LucideIcons.search),
                        label: const Text('Scan & Pick'),
                      ),
                    ],
                  ),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _ipCtrl,
                        decoration: InputDecoration(
                          labelText: 'IP Address (LAN)',
                          hintText: 'e.g. 192.168.1.50',
                          border: border,
                        ),
                        enabled: !disabled,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portCtrl,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          hintText: '9100',
                          border: border,
                        ),
                        enabled: !disabled,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text('Paper', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PaperChip(
                      label: '58 mm',
                      selected: _paper == 58,
                      onTap: disabled
                          ? null
                          : () => setState(() => _paper = 58),
                    ),
                    _PaperChip(
                      label: '80 mm',
                      selected: _paper == 80,
                      onTap: disabled
                          ? null
                          : () => setState(() => _paper = 80),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ================= UI bits =================
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PaperChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _PaperChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.primary.withOpacity(0.12)
        : const Color(0xFFF3F4F6);
    final fg = selected ? AppColors.primary : const Color(0xFF374151);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
