import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  Function(SequencerState)? onSequencerStateChanged;

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

  String? _lastConnectionError;
  String? get lastConnectionError => _lastConnectionError;

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
    _lastConnectionError = null;

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
        _lastConnectionError =
            "Could not find required UART service/characteristics. Check if device firmware is correct.";
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

      String errorMsg = e.toString();
      if (errorMsg.contains('timeout')) {
        _lastConnectionError =
            "Connection timeout. Device may be out of range or busy.";
      } else if (errorMsg.contains('connect')) {
        _lastConnectionError = "Failed to establish connection. Try again.";
      } else if (errorMsg.contains('discover')) {
        _lastConnectionError =
            "Service discovery failed. Device may be incompatible.";
      } else {
        _lastConnectionError =
            "Connection error: ${errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg}";
      }

      try {
        if (_connectedDevice != null) {
          await _connectedDevice!.disconnect();
        }
      } catch (disconnectError) {
        debugPrint("Error during cleanup disconnect: $disconnectError");
      }
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
      await Future.delayed(const Duration(milliseconds: 500));

      List<fbp.BluetoothService> services = await device
          .discoverServices()
          .timeout(const Duration(seconds: 20));

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
    _batteryTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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

      int pc = 0;
      List<Map<String, dynamic>> loopStack = [];

      while (pc < commands.length && !_stopRequested) {
        final command = commands[pc] as Map<String, dynamic>;
        final String commandName = command['command'];
        int pcIncrement = 1;

        switch (commandName) {
          case 'MOVE_TIMED':
          case 'TURN_TIMED':
          case 'WAIT':
          case 'SET_HEAD_POSITION':
          case 'SET_LED_COLOR':
          case 'DISPLAY_ICON':
          case 'PLAY_INTERNAL_SOUND':
          case 'DRIVE_DIRECT':
          case 'SET_GRIPPER':
            await _executeActionCommand(command);
            break;

          // Finite loop start
          case 'META_START_LOOP':
            loopStack.add({
              'type': 'finite',
              'startIndex': pc + 1,
              'iterationsLeft': command['params']['times'] as int,
            });
            break;

          // Infinite loop start
          case 'META_START_INFINITE_LOOP':
            loopStack.add({'type': 'infinite', 'startIndex': pc + 1});
            break;

          // Loop end
          case 'META_END_LOOP':
            if (loopStack.isNotEmpty) {
              final currentLoop = loopStack.last;
              if (currentLoop['type'] == 'infinite') {
                // Infinite loop: jump back to start
                pc = currentLoop['startIndex'] as int;
                pcIncrement = 0;
              } else if ((currentLoop['iterationsLeft'] as int) > 1) {
                // Finite loop: decrement and jump back
                currentLoop['iterationsLeft'] =
                    (currentLoop['iterationsLeft'] as int) - 1;
                pc = currentLoop['startIndex'] as int;
                pcIncrement = 0;
              } else {
                // Finite loop finished: pop and continue
                loopStack.removeLast();
              }
            }
            break;

          // Break statement
          case 'META_BREAK_LOOP':
            if (loopStack.isNotEmpty) {
              loopStack.removeLast();
              pc = _findMatchingEndLoop(commands, pc);
            }
            break;

          // If/Else-If statement (evaluate condition)
          case 'META_IF':
          case 'META_ELSE_IF':
            final String condition = command['params']['condition'] as String;
            final bool conditionMet = await _evaluateCondition(condition);
            if (!conditionMet) {
              pc = _findNextBranch(commands, pc);
            }
            break;

          case 'META_ELSE':
            pc = _findMatchingEndIf(commands, pc);
            break;

          case 'META_END_IF':
            break;

          default:
            debugPrint("Unknown command: $commandName");
            break;
        }

        pc += pcIncrement;
      }
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

  Future<void> _executeActionCommand(Map<String, dynamic> command) async {
    final String commandString = jsonEncode(command);
    await sendCommand(commandString);

    if (command.containsKey('params') && command['params'] is Map) {
      final params = command['params'] as Map<String, dynamic>;
      if (params.containsKey('duration_ms')) {
        final int duration = params['duration_ms'] as int;
        debugPrint(
          "Sequencer waiting for ${duration}ms for command '${command['command']}' to complete.",
        );
        await Future.delayed(Duration(milliseconds: duration));
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // Get sensor data from the robot (asynchronous)
  Future<int?> _getSensorData(String sensorName) async {
    if (_txCharacteristic == null) return null;

    final completer = Completer<int?>();
    StreamSubscription? subscription;

    final timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(null);
        debugPrint("Sensor read timeout for $sensorName");
      }
    });

    subscription = _txCharacteristic!.lastValueStream.listen((value) {
      try {
        final String data = String.fromCharCodes(value);
        if (data.isNotEmpty) {
          final Map<String, dynamic> response = jsonDecode(data);
          if (response['status'] == 'SENSOR_DATA' &&
              response['sensor'] == sensorName) {
            if (!completer.isCompleted) {
              timeoutTimer.cancel();
              subscription?.cancel();
              completer.complete(response['value'] as int?);
            }
          }
        }
      } catch (e) {
        debugPrint("Error parsing sensor response: $e");
      }
    });

    await sendCommand(
      '{"command":"GET_SENSOR_DATA","params":{"sensor":"$sensorName"}}',
    );

    return completer.future;
  }

  Future<bool> _evaluateCondition(String condition) async {
    try {
      final trimmedCondition = condition.trim().toLowerCase();
      if (trimmedCondition == 'true') return true;
      if (trimmedCondition == 'false') return false;

      // Replace mathRandomInt function calls with actual random numbers
      condition = _replaceMathRandomInt(condition);

      final sensorRegex = RegExp(
        r"getSensorValue\('({[^']+})'\)\s*([<>=!]+)\s*(\d+)",
      );
      final sensorMatch = sensorRegex.firstMatch(condition);

      if (sensorMatch != null) {
        final String sensorCommandJson = sensorMatch.group(1)!;
        final String operator = sensorMatch.group(2)!;
        final int compareValue = int.parse(sensorMatch.group(3)!);

        final sensorCommand = jsonDecode(sensorCommandJson);
        final String sensorName = sensorCommand['params']['sensor'] as String;

        final int? sensorValue = await _getSensorData(sensorName);

        if (sensorValue == null) {
          debugPrint("Failed to read sensor $sensorName");
          return false;
        }

        debugPrint(
          "Condition evaluation: $sensorValue $operator $compareValue",
        );

        switch (operator) {
          case '>':
            return sensorValue > compareValue;
          case '<':
            return sensorValue < compareValue;
          case '>=':
            return sensorValue >= compareValue;
          case '<=':
            return sensorValue <= compareValue;
          case '==':
            return sensorValue == compareValue;
          case '!=':
            return sensorValue != compareValue;
          default:
            debugPrint("Unknown operator: $operator");
            return false;
        }
      }

      try {
        final result = _evaluateSimpleExpression(condition);
        debugPrint("Expression '$condition' evaluated to: $result");
        return result;
      } catch (e) {
        debugPrint("Could not evaluate expression: $condition");
        return false;
      }
    } catch (e) {
      debugPrint("Error evaluating condition: $e");
      return false;
    }
  }

  String _replaceMathRandomInt(String expression) {
    final randomIntRegex = RegExp(r'mathRandomInt\((\d+),\s*(\d+)\)');

    return expression.replaceAllMapped(randomIntRegex, (match) {
      final min = int.parse(match.group(1)!);
      final max = int.parse(match.group(2)!);
      final randomValue = Random().nextInt(max - min + 1) + min;
      debugPrint('mathRandomInt($min, $max) -> $randomValue');
      return randomValue.toString();
    });
  }

  bool _evaluateSimpleExpression(String expression) {
    final stringCompRegex = RegExp(
      r'''(["'])((?:[^"'\\]|\\.)*)(\1)\s*(==|!=)\s*(["'])((?:[^"'\\]|\\.)*)\5''',
    );
    final stringMatch = stringCompRegex.firstMatch(expression);

    if (stringMatch != null) {
      final leftStr = stringMatch.group(2)!;
      final operator = stringMatch.group(4)!;
      final rightStr = stringMatch.group(6)!;

      debugPrint('String comparison: "$leftStr" $operator "$rightStr"');

      switch (operator) {
        case '==':
          return leftStr == rightStr;
        case '!=':
          return leftStr != rightStr;
        default:
          throw Exception('String comparison only supports == and !=');
      }
    }

    final expr = expression.replaceAll(' ', '');

    final comparisonRegex = RegExp(
      r'^([\d\+\-\*/\(\)]+)(==|!=|<=|>=|<|>)([\d\+\-\*/\(\)]+)$',
    );
    final match = comparisonRegex.firstMatch(expr);

    if (match == null) {
      throw Exception('Invalid expression format');
    }

    final leftExpr = match.group(1)!;
    final operator = match.group(2)!;
    final rightExpr = match.group(3)!;

    final leftValue = _evaluateMath(leftExpr);
    final rightValue = _evaluateMath(rightExpr);

    switch (operator) {
      case '==':
        return leftValue == rightValue;
      case '!=':
        return leftValue != rightValue;
      case '<':
        return leftValue < rightValue;
      case '>':
        return leftValue > rightValue;
      case '<=':
        return leftValue <= rightValue;
      case '>=':
        return leftValue >= rightValue;
      default:
        throw Exception('Unknown operator: $operator');
    }
  }

  double _evaluateMath(String expr) {
    expr = expr.replaceAll(' ', '');

    final number = double.tryParse(expr);
    if (number != null) return number;

    while (expr.contains('(')) {
      final start = expr.lastIndexOf('(');
      final end = expr.indexOf(')', start);
      if (end == -1) throw Exception('Mismatched parentheses');

      final subExpr = expr.substring(start + 1, end);
      final result = _evaluateMath(subExpr);
      expr =
          expr.substring(0, start) +
          result.toString() +
          expr.substring(end + 1);
    }

    expr = _handleOperators(expr, ['*', '/']);
    expr = _handleOperators(expr, ['+', '-']);

    return double.parse(expr);
  }

  String _handleOperators(String expr, List<String> operators) {
    for (final op in operators) {
      while (expr.contains(op)) {
        int opIndex = -1;
        for (int i = 1; i < expr.length; i++) {
          if (expr[i] == op) {
            opIndex = i;
            break;
          }
        }
        if (opIndex == -1) break;

        int leftStart = opIndex - 1;
        while (leftStart > 0 &&
            (expr[leftStart - 1].contains(RegExp(r'[\d.]')))) {
          leftStart--;
        }
        final leftStr = expr.substring(leftStart, opIndex);
        final left = double.parse(leftStr);

        int rightEnd = opIndex + 1;
        if (rightEnd < expr.length && expr[rightEnd] == '-') {
          rightEnd++;
        }
        while (rightEnd < expr.length &&
            (expr[rightEnd].contains(RegExp(r'[\d.]')))) {
          rightEnd++;
        }
        final rightStr = expr.substring(opIndex + 1, rightEnd);
        final right = double.parse(rightStr);

        double result;
        switch (op) {
          case '+':
            result = left + right;
            break;
          case '-':
            result = left - right;
            break;
          case '*':
            result = left * right;
            break;
          case '/':
            result = left / right;
            break;
          default:
            throw Exception('Unknown operator: $op');
        }

        expr =
            expr.substring(0, leftStart) +
            result.toString() +
            expr.substring(rightEnd);
      }
    }
    return expr;
  }

  int _findNextBranch(List<dynamic> commands, int startIndex) {
    int nestLevel = 0;
    int i = startIndex + 1;

    while (i < commands.length) {
      final cmd = commands[i] as Map<String, dynamic>;
      final String cmdName = cmd['command'];

      if (cmdName == 'META_IF') {
        nestLevel++;
      } else if (cmdName == 'META_END_IF') {
        if (nestLevel == 0) {
          return i;
        }
        nestLevel--;
      } else if (nestLevel == 0) {
        if (cmdName == 'META_ELSE_IF' || cmdName == 'META_ELSE') {
          return i;
        }
      }
      i++;
    }
    return commands.length;
  }

  int _findMatchingEndIf(List<dynamic> commands, int startIndex) {
    int nestLevel = 0;
    int i = startIndex + 1;

    while (i < commands.length) {
      final cmd = commands[i] as Map<String, dynamic>;
      final String cmdName = cmd['command'];

      if (cmdName == 'META_IF') {
        nestLevel++;
      } else if (cmdName == 'META_END_IF') {
        if (nestLevel == 0) {
          return i;
        }
        nestLevel--;
      }
      i++;
    }
    return commands.length;
  }

  int _findMatchingEndLoop(List<dynamic> commands, int startIndex) {
    int nestLevel = 0;
    int i = startIndex + 1;

    while (i < commands.length) {
      final cmd = commands[i] as Map<String, dynamic>;
      final String cmdName = cmd['command'];

      if (cmdName == 'META_START_LOOP' ||
          cmdName == 'META_START_INFINITE_LOOP') {
        nestLevel++;
      } else if (cmdName == 'META_END_LOOP') {
        if (nestLevel == 0) {
          return i;
        }
        nestLevel--;
      }
      i++;
    }
    return commands.length;
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
