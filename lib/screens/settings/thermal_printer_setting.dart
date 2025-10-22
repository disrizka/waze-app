// REPLACE FULL FILE WITH THIS

import 'dart:io'; // Platform & Socket (LAN printing)
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/constants/app_colors.dart';

// Bluetooth transport
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

Future<void> _ensureBluetoothPermission() async {
  if (Platform.isIOS) {
    final status = await Permission.bluetooth.request();
    if (status.isDenied) {
      throw 'Bluetooth permission denied';
    }
  } else {
    // Android 12+ pakai Bluetooth connect/scan
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // beberapa device butuh lokasi
    ].request();
  }
}

class ThermalPrinterSettingsScreen extends StatefulWidget {
  const ThermalPrinterSettingsScreen({super.key});

  @override
  State<ThermalPrinterSettingsScreen> createState() =>
      _ThermalPrinterSettingsScreenState();
}

class _ThermalPrinterSettingsScreenState
    extends State<ThermalPrinterSettingsScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');

  // MAC hasil scan (readonly, tidak ketik manual)
  final _macCtrl = TextEditingController();

  String _type = 'bluetooth'; // 'bluetooth' | 'network'
  int _paper = 58; // 58 | 80

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  bool get _isIOS => Platform.isIOS;

  // ❗️Kebijakan: disable test print Bluetooth saat iOS + dev
  bool get _btTestBlocked => _isIOS && kDebugMode && _type == 'bluetooth';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _type = sp.getString('printer.type') ?? 'bluetooth';
      _macCtrl.text = sp.getString('printer.mac') ?? '';
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
    await sp.setString('printer.mac', _macCtrl.text.trim());
    await sp.setString('printer.ip', _ipCtrl.text.trim());
    await sp.setInt(
      'printer.port',
      int.tryParse(_portCtrl.text.trim()) ?? 9100,
    );
    await sp.setInt('printer.paper', _paper);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printer settings saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ====== BLUETOOTH SCAN (Android & iOS) ======
  Future<void> _scanAndPickBluetooth() async {
    try {
      await _ensureBluetoothPermission(); // ← perbaikan: tambahkan await
      final btOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (btOn != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth first'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      List<dynamic> devices = [];

      // 1️⃣ coba ambil paired device dulu
      try {
        final paired = await PrintBluetoothThermal.pairedBluetooths;
        if (paired != null) devices = List<dynamic>.from(paired);
      } catch (_) {}

      if (devices.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Bluetooth devices found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) {
                final d = devices[i];
                final name = _btName(d);
                final mac = _btMac(d);
                return ListTile(
                  leading: const Icon(LucideIcons.printer),
                  title: Text(name.isEmpty ? 'Unknown' : name),
                  subtitle: Text(mac),
                  onTap: () => Navigator.pop(ctx, mac),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: devices.length,
            ),
          );
        },
      );

      if (picked is String && picked.isNotEmpty) {
        setState(() => _macCtrl.text = picked);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _btName(dynamic d) {
    try {
      // BluetoothInfo.name
      final n = (d as dynamic).name;
      if (n != null) return n.toString();
    } catch (_) {}
    try {
      // Map['name']
      final n = (d as Map)['name'];
      if (n != null) return n.toString();
    } catch (_) {}
    return '';
  }

  String _btMac(dynamic d) {
    try {
      // BluetoothInfo.macAddress
      final m = (d as dynamic).macAddress;
      if (m != null) return m.toString();
    } catch (_) {}
    try {
      // Beberapa lib pakai 'address'
      final m = (d as dynamic).address;
      if (m != null) return m.toString();
    } catch (_) {}
    try {
      // Map['macAddress'] / Map['address']
      final m1 = (d as Map)['macAddress'] ?? (d as Map)['address'];
      if (m1 != null) return m1.toString();
    } catch (_) {}
    return '';
  }

  /// ====== ESC/POS bytes untuk test ======
  Future<Uint8List> _buildEscPosTestBytes() async {
    final profile = await esc.CapabilityProfile.load();
    final gen = esc.Generator(
      _paper == 80 ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
      profile,
    );
    final out = <int>[];

    out.addAll(
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
    out.addAll(gen.hr());
    out.addAll(gen.text('Hello from WaveUp!'));
    out.addAll(gen.text('Paper: $_paper mm'));
    out.addAll(gen.text('Mode : ${_type.toUpperCase()}'));
    out.addAll(gen.feed(2));
    out.addAll(gen.cut());

    return Uint8List.fromList(out);
  }

  /// ====== Network RAW 9100 ======
  Future<void> _sendTcpRaw({
    required String host,
    required int port,
    required Uint8List bytes,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 200));
    } finally {
      await socket?.close();
    }
  }

  /// ====== Bluetooth write (Android & iOS BLE jika didukung printer) ======
  Future<void> _sendBluetoothRaw(Uint8List bytes) async {
    final btOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (btOn != true) throw 'Bluetooth is off';
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (ok != true) throw 'Failed to send to Bluetooth printer';
  }

  Future<void> _testPrint() async {
    // Guard kebijakan
    if (_btTestBlocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth test is disabled on iOS in Debug builds.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final data = await _buildEscPosTestBytes();

      if (_type == 'network') {
        final host = _ipCtrl.text.trim();
        final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
        if (host.isEmpty) throw 'IP Address is empty';
        await _sendTcpRaw(host: host, port: port, bytes: data);
      } else {
        // === Bluetooth path ===
        final mac = _macCtrl.text.trim();
        if (mac.isEmpty) throw 'No device selected. Please Scan & Pick first.';

        // Putuskan dulu
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}

        final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: mac,
        );
        if (connected != true) {
          throw _isIOS
              ? 'Unable to connect. On iOS, only BLE printers with supported characteristics will work.'
              : 'Unable to connect to $mac';
        }

        final status = await PrintBluetoothThermal.connectionStatus;
        if (status != true) {
          throw 'Bluetooth not connected';
        }

        await _sendBluetoothRaw(data);
      }

      // (Opsional) Preview PDF untuk verifikasi visual
      await Printing.layoutPdf(
        onLayout: (_) async => _buildMiniPdfForTest(
          mode: _type,
          paper: _paper,
          ip: _ipCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 9100,
          mac: _macCtrl.text.trim(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test print sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ===== PDF fallback builder (mini) =====
  Future<Uint8List> _buildMiniPdfForTest({
    required String mode,
    required int paper,
    required String ip,
    required int port,
    required String mac,
  }) async {
    final doc = pw.Document();
    final pageWidth = paper == 80 ? 227.0 : 164.0; // ~80mm vs 58mm
    final pageHeight = 420.0;

    final grey = PdfColor.fromHex('#6B7280');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight, marginAll: 10),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'TEST PRINT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.Text('Hello from WaveUp!'),
              pw.Text('Paper: $paper mm'),
              pw.Text('Mode: ${mode.toUpperCase()}'),
              if (mode == 'network') ...[
                pw.Text('IP: $ip'),
                pw.Text('Port: $port'),
              ] else ...[
                pw.Text('MAC: $mac'),
              ],
              pw.SizedBox(height: 10),
              pw.Text(
                'This is a minimal PDF test. For perfect thermal layout, use ESC/POS.',
                style: pw.TextStyle(fontSize: 9, color: grey),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseDisabled = _saving || _testing || _loading;
    final testDisabled = baseDisabled || _btTestBlocked; // ← tombol test
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    );

    // Tampilkan kedua opsi (Bluetooth & Network) di iOS & Android,
    // dengan peringatan kecil di iOS.
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Thermal Printer',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: testDisabled ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.printer),
                label: Text(
                  _btTestBlocked
                      ? 'Test Print (iOS Dev Disabled)'
                      : 'Test Print',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: baseDisabled ? null : _save,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeaderCard(
                    title: 'Thermal Printer',
                    subtitle:
                        'Configure connection & paper size. Keep it simple.',
                    icon: LucideIcons.printer,
                  ),

                  if (_isIOS)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        _btTestBlocked
                            ? 'iOS (Debug): Bluetooth test print is disabled. Use Network (RAW 9100) or build Release to test Bluetooth.'
                            : 'iOS notice: Many ESC/POS Bluetooth printers are not supported unless BLE with proper characteristics. Prefer Network (RAW 9100) or AirPrint.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),

                  _SectionCard(
                    title: 'Connection',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          segments: segments,
                          selected: {_type},
                          onSelectionChanged: baseDisabled
                              ? null
                              : (s) => setState(() => _type = s.first),
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            side: MaterialStateProperty.all(
                              const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedCrossFade(
                          crossFadeState: _type == 'bluetooth'
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 200),
                          firstChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Readonly field untuk MAC yang diisi dari Scan
                              TextField(
                                controller: _macCtrl,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Selected Device',
                                  hintText: 'No device selected',
                                  prefixIcon: const Icon(LucideIcons.bluetooth),
                                  border: border,
                                  enabledBorder: border,
                                  disabledBorder: border,
                                  helperText:
                                      'Tap "Scan & Pick" to select a Bluetooth printer.',
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: baseDisabled
                                    ? null
                                    : _scanAndPickBluetooth,
                                icon: const Icon(LucideIcons.search),
                                label: const Text('Scan & Pick'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _ipCtrl,
                                enabled: !baseDisabled,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'IP Address',
                                  hintText: 'e.g. 192.168.1.50',
                                  prefixIcon: const Icon(LucideIcons.network),
                                  border: border,
                                  enabledBorder: border,
                                  focusedBorder: border.copyWith(
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  helperText:
                                      'Make sure the printer is reachable on your LAN.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _portCtrl,
                                enabled: !baseDisabled,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Port',
                                  hintText: '9100',
                                  prefixIcon: const Icon(LucideIcons.hash),
                                  border: border,
                                  enabledBorder: border,
                                  focusedBorder: border.copyWith(
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  helperText:
                                      'Most thermal printers use RAW 9100.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _SectionCard(
                    title: 'Paper',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PaperChip(
                          label: '58 mm',
                          selected: _paper == 58,
                          onTap: baseDisabled
                              ? null
                              : () => setState(() => _paper = 58),
                        ),
                        _PaperChip(
                          label: '80 mm',
                          selected: _paper == 80,
                          onTap: baseDisabled
                              ? null
                              : () => setState(() => _paper = 80),
                        ),
                      ],
                    ),
                  ),

                  _SectionCard(
                    title: 'Tips',
                    child: _TipsList(
                      tips: ['Use ESC/POS for accurate thermal layout.'],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Simple header card
class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section card with title and inner content
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      margin: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF333A46),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Minimal soft card
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  const _GlassCard({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
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

class _TipsList extends StatelessWidget {
  final List<String> tips;
  const _TipsList({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tips
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(color: Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
