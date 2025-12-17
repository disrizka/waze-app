package com.wave.up

import android.bluetooth.BluetoothAdapter
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "bt/paired"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBonded" -> {
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null) {
                                // Device tidak punya Bluetooth
                                result.success(emptyList<Map<String, String>>())
                                return@setMethodCallHandler
                            }

                            // NOTE: Android 12+ (API 31+) butuh permission BLUETOOTH_CONNECT
                            // Pastikan sudah di-request lewat permission_handler di Dart
                            val bonded = adapter.bondedDevices
                            val list = bonded.map {
                                mapOf(
                                    "name" to (it.name ?: ""),
                                    "address" to (it.address ?: "")
                                )
                            }

                            result.success(list)
                        } catch (e: SecurityException) {
                            // Kalau belum dapat izin CONNECT
                            result.error(
                                "BT_SECURITY",
                                "Missing BLUETOOTH_CONNECT permission",
                                null
                            )
                        } catch (e: Exception) {
                            result.error("BT_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
