import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

// UUIDs remain the same
final fbp.Guid nordicUartServiceUuid = fbp.Guid(
  "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
);
final fbp.Guid nordicUartRxCharUuid = fbp.Guid(
  "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
);
final fbp.Guid nordicUartTxCharUuid = fbp.Guid(
  "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
);

enum BluetoothConnectionState { disconnected, scanning, connecting, connected }

enum SequencerState { idle, running }

class BluetoothService with ChangeNotifier {
  BluetoothService._privateConstructor();
  static final BluetoothService _instance =
      BluetoothService._privateConstructor();
  static BluetoothService get instance => _instance;

  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  BluetoothConnectionState get connectionState => _connectionState;

  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _connectionStateSubscription;

  List<fbp.ScanResult> _scanResults = [];
  List<fbp.ScanResult> get scanResults => _scanResults;

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  fbp.BluetoothCharacteristic? _rxCharacteristic;
  fbp.BluetoothCharacteristic? _txCharacteristic;

  SequencerState _sequencerState = SequencerState.idle;
  SequencerState get sequencerState => _sequencerState;

  // NEW: External callback that UI layers (including WebView bridge) can set to
  // receive immediate sequencer state updates.
  Function(SequencerState)? onSequencerStateChanged;

  // Helper to update the sequencer state, notify Flutter listeners, and call
  // the external callback if present.
  void _updateSequencerState(SequencerState newState) {
    if (_sequencerState == newState) return;
    _sequencerState = newState;
    notifyListeners();
    try {
      onSequencerStateChanged?.call(_sequencerState);
    } catch (e) {
      debugPrint('Error in onSequencerStateChanged callback: $e');
    }
  }

  int _batteryLevel = -1;
  int get batteryLevel => _batteryLevel;

  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;
  bool _stopRequested = false;

  void _updateConnectionState(BluetoothConnectionState newState) {
    if (_connectionState == newState) return;
    _connectionState = newState;
    notifyListeners();
  }

  Future<void> startScan() async {
    if (fbp.FlutterBluePlus.adapterStateNow != fbp.BluetoothAdapterState.on) {
      debugPrint("Bluetooth adapter is off.");
      try {
        await fbp.FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint("Error turning on Bluetooth: $e");
      }
    }
    _updateConnectionState(BluetoothConnectionState.scanning);
    _scanResults = [];
    notifyListeners();

    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Error starting scan: $e");
      _updateConnectionState(BluetoothConnectionState.disconnected);
      return;
    }

    _scanResultsSubscription?.cancel();
    _scanResultsSubscription = fbp.FlutterBluePlus.scanResults.listen(
      (results) {
        _scanResults = results;
        notifyListeners();
      },
      onError: (e) {
        debugPrint("Scan error: $e");
        stopScan();
      },
    );

    fbp.FlutterBluePlus.isScanning.where((val) => val == false).first.then((_) {
      _scanResultsSubscription?.cancel();
      if (_connectionState == BluetoothConnectionState.scanning) {
        _updateConnectionState(BluetoothConnectionState.disconnected);
      }
    });
  }

  Future<void> stopScan() async {
    await fbp.FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    if (_connectionState == BluetoothConnectionState.scanning) {
      _updateConnectionState(BluetoothConnectionState.disconnected);
    }
  }

  Future<bool> connect(fbp.BluetoothDevice device) async {
    if (isConnected) {
      if (device.remoteId == _connectedDevice?.remoteId) {
        return true;
      }
      await disconnect();
    }

    _updateConnectionState(BluetoothConnectionState.connecting);

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: fbp.License.free,
      );

      _connectedDevice = device;
      bool success = await _discoverServicesAndCharacteristics(device);

      if (!success) {
        await disconnect();
        return false;
      }

      _updateConnectionState(BluetoothConnectionState.connected);

      await sendCommand('{"command":"GET_BATTERY_STATUS","params":{}}');
      _startBatteryMonitor();

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          debugPrint("Device disconnected unexpectedly.");
          _cleanUpConnection();
        }
      });

      return true;
    } catch (e) {
      debugPrint("Connection failed with exception: $e");
      _cleanUpConnection();
      return false;
    }
  }

  Future<void> disconnect() async {
    await stopScan();
    _stopBatteryMonitor();
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _cleanUpConnection();
  }

  void _cleanUpConnection() {
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _batteryLevel = -1;
    _updateConnectionState(BluetoothConnectionState.disconnected);
  }

  Future<bool> _discoverServicesAndCharacteristics(
    fbp.BluetoothDevice device,
  ) async {
    try {
      List<fbp.BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == nordicUartServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == nordicUartRxCharUuid) {
              _rxCharacteristic = char;
            } else if (char.uuid == nordicUartTxCharUuid) {
              _txCharacteristic = char;
            }
          }
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        debugPrint("Error: Could not find all required characteristics.");
        return false;
      }

      await _txCharacteristic!.setNotifyValue(true);
      _txCharacteristic!.lastValueStream.listen((value) {
        final String data = String.fromCharCodes(value);
        if (data.isNotEmpty) {
          try {
            final Map<String, dynamic> response = jsonDecode(data);
            if (response['status'] == 'BATTERY') {
              _batteryLevel = response['level'] as int;
              notifyListeners();
            }
          } catch (e) {
            // Silently ignore non-json/malformed responses
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint("Error during service discovery: $e");
      return false;
    }
  }

  Timer? _batteryTimer;

  void _startBatteryMonitor() {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (isConnected) {
        sendCommand('{"command":"GET_BATTERY_STATUS","params":{}}');
      } else {
        timer.cancel();
      }
    });
  }

  void _stopBatteryMonitor() {
    _batteryTimer?.cancel();
  }

  Future<void> runCommandSequence(String commandJsonArray) async {
    if (_sequencerState == SequencerState.running) {
      return;
    }
    if (!isConnected) {
      return;
    }

    _updateSequencerState(SequencerState.running);
    _stopRequested = false;

    debugPrint("--- Starting Command Sequence ---");

    try {
      List<dynamic> commands = jsonDecode(commandJsonArray);
      await _executeBlock(commands, 0);
    } catch (e) {
      debugPrint("Error processing command sequence: $e");
    }

    debugPrint("--- Sequence Finished ---");
    if (!_stopRequested) {
      await sendCommand(
        '{"command":"DRIVE_DIRECT","params":{"left_speed":0,"right_speed":0}}',
      );
    }

    _updateSequencerState(SequencerState.idle);
    _stopRequested = false;
  }

  Future<int> _executeBlock(List<dynamic> commands, int index) async {
    int i = index;
    while (i < commands.length) {
      if (_stopRequested) return commands.length;

      final command = commands[i] as Map<String, dynamic>;
      final String commandName = command['command'];

      if (commandName == 'META_START_LOOP') {
        final int times = command['params']['times'];
        for (int j = 0; j < times; j++) {
          if (_stopRequested) break;
          i = await _executeBlock(commands, i + 1);
        }
        int nestLevel = 0;
        i++;
        while (i < commands.length) {
          final nextCmd = commands[i] as Map<String, dynamic>;
          if (nextCmd['command'] == 'META_START_LOOP') nestLevel++;
          if (nextCmd['command'] == 'META_END_LOOP') {
            if (nestLevel == 0) break;
            nestLevel--;
          }
          i++;
        }
      } else if (commandName == 'META_END_LOOP') {
        return i;
      } else {
        final String commandString = jsonEncode(command);
        await sendCommand(commandString);

        if (command.containsKey('params') && command['params'] is Map) {
          final params = command['params'] as Map<String, dynamic>;
          if (params.containsKey('duration_ms')) {
            final int duration = params['duration_ms'] as int;
            debugPrint(
              "Sequencer waiting for ${duration}ms for command '$commandName' to complete.",
            );
            await Future.delayed(Duration(milliseconds: duration));
          } else {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      i++;
    }
    return i;
  }

  void stopSequence() {
    if (_sequencerState == SequencerState.running) {
      _stopRequested = true;
      sendCommand(
        '{"command":"DRIVE_DIRECT","params":{"left_speed":0,"right_speed":0}}',
      );
      _updateSequencerState(SequencerState.idle);
    }
  }

  Future<void> sendCommand(String jsonCommand) async {
    if (_rxCharacteristic == null) {
      debugPrint("Cannot send command: RX characteristic not found.");
      return;
    }
    try {
      final commandWithDelimiter = '$jsonCommand\n';

      await _rxCharacteristic!.write(
        commandWithDelimiter.codeUnits,
        withoutResponse: true,
      );
      debugPrint("Sent command: $jsonCommand");
    } catch (e) {
      debugPrint("Error sending command: $e");
    }
  }
}
