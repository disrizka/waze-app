import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceInfo {
  final String id; // iOS UUID
  final String name; // boleh kosong
  BleDeviceInfo({required this.id, required this.name});
}

class IosBlePrinterService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<ScanResult>>? _scanSub;

  bool get isConnected => _device != null && _device!.isConnected;
  String? get connectedDeviceId => _device?.remoteId.str;

  /// Scan BLE devices (default 6 detik).
  Future<List<BleDeviceInfo>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final results = <BleDeviceInfo>[];

    // pastikan stop scan dulu
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    final done = Completer<void>();
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        final dev = r.device;

        // Nama yang bisa dipakai: device.platformName atau adv name dari advert data
        final advName = r.advertisementData.advName; // biasanya ada
        final name =
            (dev.platformName.isNotEmpty ? dev.platformName : advName) ?? '';

        final id = dev.remoteId.str;
        if (results.indexWhere((e) => e.id == id) < 0) {
          results.add(BleDeviceInfo(id: id, name: name));
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: timeout);
    Future.delayed(timeout).then((_) => done.complete());
    await done.future;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;

    return results;
  }

  /// Connect ke deviceId (UUID), discover services, pilih characteristic tulis.
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await disconnect(); // putuskan koneksi sebelumnya jika ada

    final dev = BluetoothDevice.fromId(deviceId);
    _device = dev;

    await dev.connect(timeout: timeout, license: License.free);

    final services = await dev.discoverServices();

    // Prefer writeWithoutResponse
    BluetoothCharacteristic? chosen;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.writeWithoutResponse == true) {
          chosen = c;
          break;
        }
      }
      if (chosen != null) break;
    }

    // Fallback: write
    chosen ??= () {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.write == true) {
            return c;
          }
        }
      }
      return null;
    }();

    // Fallback lagi: FFE0/FFE1 (umum di printer BLE)
    if (chosen == null) {
      final ffe0 = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
      final ffe1 = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");
      for (final s in services) {
        if (s.uuid == ffe0) {
          for (final c in s.characteristics) {
            if (c.uuid == ffe1) {
              chosen = c;
              break;
            }
          }
        }
        if (chosen != null) break;
      }
    }

    if (chosen == null) {
      await dev.disconnect();
      _device = null;
      throw 'No writable BLE characteristic found on this device';
    }

    _writeChar = chosen;
  }

  /// Tulis data ke printer (chunk 20 bytes).
  Future<void> write(Uint8List data) async {
    if (_device == null || _writeChar == null) {
      throw 'Printer BLE is not connected';
    }

    const int chunk = 20; // iOS aman 20 byte per write
    for (int offset = 0; offset < data.length; offset += chunk) {
      final end = (offset + chunk < data.length) ? offset + chunk : data.length;
      final part = data.sublist(offset, end);

      try {
        if (_writeChar!.properties.writeWithoutResponse) {
          await _writeChar!.write(part, withoutResponse: true);
        } else {
          await _writeChar!.write(part, withoutResponse: false);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BLE] write part ${offset}..${end} error: $e');
        }
        rethrow;
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> disconnect() async {
    try {
      if (_device != null) {
        await _device!.disconnect();
      }
    } catch (_) {}
    _device = null;
    _writeChar = null;
  }
}
