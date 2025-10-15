import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

final fbp.Guid nordicUartServiceUuid = fbp.Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
final fbp.Guid nordicUartRxCharUuid = fbp.Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
final fbp.Guid nordicUartTxCharUuid = fbp.Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  connectionFailed,
}

enum SequencerState {
  idle,
  running,
}

class BluetoothService with ChangeNotifier {
  BluetoothService._privateConstructor();
  static final BluetoothService _instance = BluetoothService._privateConstructor();
  static BluetoothService get instance => _instance;

  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
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

  bool _stopRequested = false;

  void _updateConnectionState(BluetoothConnectionState newState) {
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
    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Error starting scan: $e");
      _updateConnectionState(BluetoothConnectionState.disconnected);
      return;
    }
    _scanResultsSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      },
      onError: (e) {
        debugPrint("Scan error: $e");
        stopScan();
      }
    );
    fbp.FlutterBluePlus.isScanning.where((val) => val == false).first.then((_) {
      _scanResultsSubscription?.cancel();
      if (_connectionState == BluetoothConnectionState.scanning) {
        _updateConnectionState(BluetoothConnectionState.disconnected);
      }
    });
  }

  void stopScan() {
    fbp.FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    if (_connectionState == BluetoothConnectionState.scanning) {
      _updateConnectionState(BluetoothConnectionState.disconnected);
    }
  }

  Future<void> connect(fbp.BluetoothDevice device) async {
    if (_connectionState == BluetoothConnectionState.connecting || _connectionState == BluetoothConnectionState.connected) {
      return;
    }

    _updateConnectionState(BluetoothConnectionState.connecting);

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: fbp.License.free,
      );
      _connectedDevice = device;
      await _discoverServicesAndCharacteristics(device);      
      _updateConnectionState(BluetoothConnectionState.connected);
      
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          debugPrint("Device disconnected unexpectedly.");
          _cleanUpConnection();
        }
      });

    } catch (e) {
      debugPrint("Connection failed with exception: $e");
      _updateConnectionState(BluetoothConnectionState.connectionFailed);
    }
  }

  Future<void> disconnect() async {
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
    _updateConnectionState(BluetoothConnectionState.disconnected);
  }
  
  Future<void> _discoverServicesAndCharacteristics(fbp.BluetoothDevice device) async {
    List<fbp.BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == nordicUartServiceUuid) {
        debugPrint("Found Nordic UART Service!");
        for (var char in service.characteristics) {
          if (char.uuid == nordicUartRxCharUuid) {
            _rxCharacteristic = char;
            debugPrint("  - Found RX Characteristic");
          } else if (char.uuid == nordicUartTxCharUuid) {
            _txCharacteristic = char;
            debugPrint("  - Found TX Characteristic");
          }
        }
      }
    }
    if (_txCharacteristic != null) {
      await _txCharacteristic!.setNotifyValue(true);
      _txCharacteristic!.lastValueStream.listen((value) {
        final String data = String.fromCharCodes(value);
        if (data.isNotEmpty) {
           debugPrint("Received data from robot: $data");
        }
      });
    }
    if (_rxCharacteristic == null || _txCharacteristic == null) {
      debugPrint("Error: Could not find all required characteristics. Disconnecting.");
      disconnect();
    }
  }

  Future<void> runCommandSequence(String commandJsonArray) async {
    if (_sequencerState == SequencerState.running) {
      debugPrint("Sequencer is already running.");
      return;
    }
    if (connectionState != BluetoothConnectionState.connected) {
      debugPrint("Cannot run sequence: Robot not connected.");
      return;
    }

    _sequencerState = SequencerState.running;
    _stopRequested = false;
    notifyListeners();
    
    debugPrint("--- Starting Command Sequence ---");
    
    try {
      List<dynamic> commands = jsonDecode(commandJsonArray);

      await _executeBlock(commands, 0);
    } catch (e) {
      debugPrint("Error processing command sequence: $e");
    }
    
    debugPrint("--- Sequence Finished ---");
    await sendCommand('{"command":"DRIVE_DIRECT","params":{"left_speed":0,"right_speed":0}}');
    if (!_stopRequested) {
      await sendCommand('{"command":"DRIVE_DIRECT","params":{"left_speed":0,"right_speed":0}}');
    }

    _sequencerState = SequencerState.idle;
    _stopRequested = false;
    notifyListeners();
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
      } else if (commandName == 'WAIT') {
        final int duration = command['params']['duration_ms'];
        await Future.delayed(Duration(milliseconds: duration));
      } else {
        final String commandString = jsonEncode(command);
        await sendCommand(commandString);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      i++;
    }
    return i;
  }

  void stopSequence() {
    if (_sequencerState == SequencerState.running) {
      _stopRequested = true;
    }
  }

  Future<void> sendCommand(String jsonCommand) async {
    if (_rxCharacteristic == null) {
      debugPrint("Cannot send command: RX characteristic not found.");
      return;
    }
    try {
      await _rxCharacteristic!.write(jsonCommand.codeUnits);
      debugPrint("Sent command: $jsonCommand");
    } catch (e) {
      debugPrint("Error sending command: $e");
    }
  }
}