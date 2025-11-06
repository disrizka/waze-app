// lib/services/pos_print_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PosPrintService {
  /// Build sample/test bytes; ganti sesuai kebutuhan produksi kamu
  static Future<Uint8List> buildTestBytes({bool is80mm = false}) async {
    final profile = await esc.CapabilityProfile.load();
    final gen = esc.Generator(
      is80mm ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
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
    out.addAll(gen.feed(1));
    out.addAll(gen.cut());

    return Uint8List.fromList(out);
  }

  /// Kirim raw bytes ke printer network (RAW 9100)
  static Future<void> sendTcpRaw({
    required String host,
    int port = 9100,
    required Uint8List bytes,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.add(bytes);
    await socket.flush();
    // tunggu sebentar agar buffer terkirim penuh
    await Future.delayed(const Duration(milliseconds: 200));
    await socket.close();
  }

  /// Kirim raw bytes via Bluetooth (pastikan sudah connect dulu)
  static Future<void> sendBluetoothRaw(Uint8List bytes) async {
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception('Failed to write bytes to Bluetooth printer');
    }
  }

  /// Scan & connect Bluetooth (sederhana)
  static Future<void> connectBluetooth(String macAddress) async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw Exception('Bluetooth is off');
    }
    // Disconnect kalau ada koneksi lama
    await PrintBluetoothThermal.disconnect;
    final r = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );
    if (r != true) {
      throw Exception('Unable to connect to printer: $macAddress');
    }
  }

  /// Optional helper untuk scan daftar perangkat
  Future<List<Map<String, String>>> scanBluetooth() async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) return [];
    final devices =
        await PrintBluetoothThermal.pairedBluetooths; // List<BluetoothInfo>?
    return (devices ?? [])
        .map<Map<String, String>>(
          (e) => {
            'name': (e.name ?? '').isNotEmpty ? e.name! : 'Unknown',
            'mac': e.macAdress ?? '', // di iOS bisa kosong
          },
        )
        .toList();
  }
}
