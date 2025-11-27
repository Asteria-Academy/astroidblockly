import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import '../router/app_router.dart';
import '../l10n/generated/app_localizations.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final BluetoothService _btService = BluetoothService.instance;

  @override
  void initState() {
    super.initState();
    _btService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _btService.removeListener(_onServiceChanged);
    _btService.stopScan();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleConnectToDevice(fbp.BluetoothDevice device) async {
    await _btService.stopScan();

    if (!mounted) return;

    final success = await Navigator.pushNamed(
      context,
      AppRoutes.connecting,
      arguments: device,
    );

    if (mounted && success == true) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.connectSuccessMessage(device.platformName)),
            backgroundColor: Colors.green.shade700,
          ),
        );
    } else if (mounted && success == false) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.connectFailedMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1464), Color(0xFF0a0a2e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_btService.isConnected) _buildConnectionStatus(),
              Expanded(child: _buildMainContent()),
              if (!_btService.isConnected) _buildScanButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.connectTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x334CAF50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.connectConnectedTo(_btService.connectedDevice?.platformName ?? "Unknown"),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (_btService.batteryLevel >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      l10n.connectBattery(_btService.batteryLevel),
                      style: const TextStyle(
                          color: Color(0xB3FFFFFF), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _btService.disconnect,
            child: Text(l10n.connectDisconnect, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_btService.isConnected) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy, size: 100, color: Colors.cyanAccent),
          const SizedBox(height: 20),
          Text(l10n.connectRobotReady, style: const TextStyle(color: Colors.white, fontSize: 22)),
          Text(l10n.connectGoBack, style: const TextStyle(color: Colors.white70)),
        ],
      );
    }
    
    final bool isScanning = _btService.connectionState == BluetoothConnectionState.scanning;
    
    if (isScanning && _btService.scanResults.isEmpty) {
      return Center(child: Text(l10n.connectSearching, style: const TextStyle(color: Colors.white70)));
    }

    if (!isScanning && _btService.scanResults.isEmpty) {
      return _buildEmptyState();
    }

    return _buildScanResultsList();
  }

  ListView _buildScanResultsList() {
    final List<fbp.ScanResult> filteredResults = _btService.scanResults
        .where((r) => r.device.platformName.isNotEmpty)
        .toList();

    filteredResults.sort((a, b) {
      final aIsAstroid = a.device.platformName == "AstroidRobot-Beta";
      final bIsAstroid = b.device.platformName == "AstroidRobot-Beta";
      if (aIsAstroid && !bIsAstroid) return -1;
      if (!aIsAstroid && bIsAstroid) return 1;
      return b.rssi.compareTo(a.rssi);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final result = filteredResults[index];
        final isAstroid = result.device.platformName == "AstroidRobot-Beta";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isAstroid ? const Color(0x331A3D6F) : const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAstroid ? Colors.cyanAccent : Colors.white24,
              width: isAstroid ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
              isAstroid ? Icons.smart_toy_sharp : Icons.bluetooth,
              color: isAstroid ? Colors.cyanAccent : Colors.white70,
            ),
            title: Text(
              result.device.platformName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isAstroid ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              result.device.remoteId.toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppLocalizations.of(context)!.connectSignalStrength(result.rssi),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Icon(_getSignalIcon(result.rssi), color: _getSignalColor(result.rssi), size: 20),
              ],
            ),
            onTap: () => _handleConnectToDevice(result.device),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 80, color: Color(0x4DFFFFFF)),
          const SizedBox(height: 20),
          Text(l10n.connectNoRobots,
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 18)),
          const SizedBox(height: 8),
          Text(l10n.connectMakeSure,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    final bool isScanning = _btService.connectionState == BluetoothConnectionState.scanning;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isScanning ? null : _btService.startScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            disabledBackgroundColor: const Color(0x8000BCD4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isScanning
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 12),
                    Text(l10n.connectScanning, style: const TextStyle(color: Colors.white)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.connectScanButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
      ),
    );
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -65) return Icons.signal_cellular_4_bar;
    if (rssi >= -75) return Icons.signal_cellular_alt_2_bar;
    if (rssi >= -85) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_0_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -65) return Colors.greenAccent;
    if (rssi >= -85) return Colors.amber;
    return Colors.redAccent;
  }
}