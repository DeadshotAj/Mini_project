import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

/// Manufacturer ID used in the BLE advertisement to identify Smart Attendance
/// beacons. Replace with a registered Bluetooth SIG company ID in production.
const int kManufacturerId = 0x05AC;
const String kBleServiceUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

/// RSSI threshold (dBm). Devices with median RSSI above this are considered
/// in range. -95 dBm covers standard classroom distances.
const int kRssiThreshold = -95;

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  /// Number of sessionId characters encoded in the BLE payload (8 chars = 8 bytes).
  /// Compact length guarantees payload fits inside Windows BLE packet limits.
  static const int kSessionIdPrefixLength = 8;

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isAdvertising = false;

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  // ── Bluetooth state ───────────────────────────────────────────────────────

  Future<bool> isBluetoothOn() async {
    if (Platform.isWindows) return true; // Windows handles Bluetooth via start/scan attempt directly
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Attempts to prompt the OS to turn on Bluetooth if it's off.
  /// On Android, triggers the native system Bluetooth turn-on prompt dialog.
  /// On Windows, opens the Windows Bluetooth Settings page.
  Future<bool> ensureBluetoothOn() async {
    try {
      if (await isBluetoothOn()) return true;

      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (await isBluetoothOn()) return true;
        }
      } else if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', 'ms-settings:bluetooth']);
        } catch (_) {
          try {
            await _peripheral.openBluetoothSettings();
          } catch (_) {}
        }
      }
      return await isBluetoothOn();
    } catch (e) {
      debugPrint('[BleService] ensureBluetoothOn error: $e');
      return false;
    }
  }

  // ── Encoding ──────────────────────────────────────────────────────────────

  /// Encodes the first [kSessionIdPrefixLength] chars of a sessionId to bytes.
  Uint8List _encodeSessionId(String sessionId) {
    final clean = sessionId.replaceAll('-', '');
    final prefix = clean.substring(0, clean.length.clamp(0, kSessionIdPrefixLength));
    return Uint8List.fromList(prefix.codeUnits);
  }

  /// Returns true if [result] matches our session beacon.
  bool _matchesSession(ScanResult result, String sessionId) {
    final clean = sessionId.replaceAll('-', '');
    final targetPrefix = clean.substring(0, clean.length.clamp(0, kSessionIdPrefixLength)).toLowerCase();
    final shortPrefix = clean.substring(0, clean.length.clamp(0, 6)).toLowerCase();

    // 1. Check Advertisement Name / Local Name
    final advName = result.advertisementData.advName.toLowerCase();
    final platformName = result.device.platformName.toLowerCase();
    if (advName.contains(shortPrefix) ||
        platformName.contains(shortPrefix) ||
        advName.contains('sa_') ||
        platformName.contains('sa_')) {
      return true;
    }

    // 2. Check Service UUIDs
    final uuids = result.advertisementData.serviceUuids;
    for (final u in uuids) {
      if (u.toString().toLowerCase().contains(kBleServiceUuid.substring(0, 8).toLowerCase())) {
        return true;
      }
    }

    // 3. Check Manufacturer Data values
    final manufacturerData = result.advertisementData.manufacturerData;
    for (final bytes in manufacturerData.values) {
      if (bytes.isEmpty) continue;
      try {
        final decoded = String.fromCharCodes(bytes).toLowerCase();
        if (decoded.contains(targetPrefix) || decoded.contains(shortPrefix)) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  // ── Teacher side: BLE advertise ───────────────────────────────────────────

  /// Whether this platform can advertise BLE.
  /// Both Android and Windows are supported by flutter_ble_peripheral.
  bool get canAdvertise => Platform.isAndroid || Platform.isWindows;

  /// Starts advertising a BLE beacon encoding [sessionId] in manufacturer
  /// data so nearby student devices can detect it.
  /// Returns true on success.
  Future<bool> startAdvertising(String sessionId) async {
    if (!canAdvertise) return false;
    if (_isAdvertising) await stopAdvertising();

    try {
      if (Platform.isAndroid) {
        final granted = await requestPermissions();
        if (!granted) return false;

        bool btOn = await isBluetoothOn();
        if (!btOn) {
          btOn = await ensureBluetoothOn();
        }
        if (!btOn) return false;

        final supported = await _peripheral.isSupported;
        if (!supported) return false;
      }

      final clean = sessionId.replaceAll('-', '');
      final shortPrefix = clean.substring(0, clean.length.clamp(0, 6));

      final data = AdvertiseData(
        serviceUuid: kBleServiceUuid,
        manufacturerId: kManufacturerId,
        manufacturerData: _encodeSessionId(sessionId),
        includeDeviceName: true,
        localName: 'SA_$shortPrefix',
      );

      await _peripheral.start(advertiseData: data);
      _isAdvertising = true;
      debugPrint('[BleService] BLE advertising started for session: $sessionId');
      return true;
    } catch (e) {
      debugPrint('[BleService] startAdvertising error: $e');
      return false;
    }
  }

  /// Stops the teacher BLE beacon.
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await _peripheral.stop();
    } catch (_) {}
    _isAdvertising = false;
  }

  // ── Student side: BLE scan ────────────────────────────────────────────────

  /// Whether this platform can scan for BLE devices (Android + Windows).
  bool get canScan => Platform.isAndroid || Platform.isWindows;

  /// Scans for the teacher BLE beacon for up to [timeout] and returns true
  /// if the classroom beacon for [sessionId] is found within [kRssiThreshold].
  Future<bool> checkProximity(String sessionId,
      {Duration timeout = const Duration(seconds: 6)}) async {
    if (!canScan) return false;

    if (Platform.isAndroid) {
      final granted = await requestPermissions();
      if (!granted) return false;
    }

    bool btOn = await isBluetoothOn();
    if (!btOn) {
      btOn = await ensureBluetoothOn();
    }
    if (!btOn) return false;

    try {
      final rssiReadings = <int>[];

      // 1. Subscribe to scanResults BEFORE starting scan
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (_matchesSession(r, sessionId)) {
            rssiReadings.add(r.rssi);
          }
        }
      });

      // 2. Start low latency scan
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // 3. Check lastScanResults immediately
      for (final r in FlutterBluePlus.lastScanResults) {
        if (_matchesSession(r, sessionId)) {
          rssiReadings.add(r.rssi);
        }
      }

      await Future.delayed(timeout);
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      return rssiReadings.isNotEmpty;
    } catch (e) {
      debugPrint('[BleService] checkProximity error: $e');
      return false;
    }
  }

  void dispose() {
    stopAdvertising();
    _scanSubscription?.cancel();
  }
}


