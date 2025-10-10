import 'package:astroid_test_webview_app/router/app_router.dart';
import 'package:astroid_test_webview_app/services/bluetooth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService, BluetoothConnectionState;

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final BluetoothService _btService = BluetoothService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      appBar: AppBar(
        title: const Text("Connect to Robot"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _btService.stopScan();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: AnimatedBuilder(
        animation: _btService,
        builder: (context, child) {
          return Center(
            child: Column(
              children: [
                _buildConnectionStatus(),
                _buildScanButton(),
                _buildScanResultList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (_btService.connectionState == BluetoothConnectionState.connected) {
      return Card(
        color: Colors.green[800],
        margin: const EdgeInsets.all(16),
        child: ListTile(
          leading: const Icon(Icons.bluetooth_connected, color: Colors.white),
          title: Text("Connected to ${_btService.connectedDevice?.platformName ?? 'Robot'}", style: const TextStyle(color: Colors.white)),
          trailing: TextButton(
            onPressed: _btService.disconnect,
            child: const Text("Disconnect", style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildScanButton() {
    if (_btService.connectionState == BluetoothConnectionState.connected) {
      return const SizedBox.shrink();
    }
    
    final bool isScanning = _btService.connectionState == BluetoothConnectionState.scanning;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: isScanning
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.bluetooth_searching),
        label: Text(isScanning ? "Scanning..." : "Scan for Robots"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(200, 50),
          backgroundColor: isScanning ? Colors.grey[700] : Colors.blueAccent,
        ),
        onPressed: isScanning ? null : _btService.startScan,
      ),
    );
  }

  // THIS METHOD IS NOW MUCH SIMPLER
  Widget _buildScanResultList() {
    if (_btService.connectionState == BluetoothConnectionState.connected) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text("Ready to receive commands!", style: TextStyle(color: Colors.white70, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    List<ScanResult> namedResults = _btService.scanResults
        .where((r) => r.device.platformName.isNotEmpty)
        .toList();
    namedResults.sort((a, b) {
      if (a.device.platformName == "AstroidRobot-Beta") return -1;
      if (b.device.platformName == "AstroidRobot-Beta") return 1;
      return b.rssi.compareTo(a.rssi);
    });

    if (_btService.connectionState == BluetoothConnectionState.scanning && namedResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("Searching for Astroid robots...", style: TextStyle(color: Colors.white70)),
      );
    }

    if (namedResults.isEmpty && _btService.connectionState != BluetoothConnectionState.scanning) {
       return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No robots found. Make sure your robot is on and press Scan.", style: TextStyle(color: Colors.white70)),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: namedResults.length,
        itemBuilder: (context, index) {
          final result = namedResults[index];
          final isAstroid = result.device.platformName == "AstroidRobot-Beta";

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            color: isAstroid ? const Color(0xFF1A3D6F) : const Color(0xFF1A244A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isAstroid ? const BorderSide(color: Colors.cyanAccent, width: 1.5) : BorderSide.none
            ),
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined, color: Colors.white),
              title: Text(result.device.platformName, style: TextStyle(
                fontWeight: isAstroid ? FontWeight.bold : FontWeight.normal,
                color: Colors.white
              )),
              subtitle: Text(result.device.remoteId.toString(), style: const TextStyle(color: Colors.white70)),
              trailing: Text("${result.rssi} dBm", style: const TextStyle(color: Colors.cyan)),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.connecting,
                  arguments: result.device,
                );
              },
            ),
          );
        },
      ),
    );
  }
}