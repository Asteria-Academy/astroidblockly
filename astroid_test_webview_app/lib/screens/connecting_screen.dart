import 'dart:async';
import 'package:astroid_test_webview_app/services/bluetooth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key, required this.device});

  final fbp.BluetoothDevice device;

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  final BluetoothService _btService = BluetoothService.instance;
  bool _isNavigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _btService.connect(widget.device);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1433),
        body: AnimatedBuilder(
          animation: _btService,
          builder: (context, child) {
            if (_btService.connectionState ==
                    BluetoothConnectionState.connected &&
                !_isNavigationScheduled) {
              _isNavigationScheduled = true;
              final navigator = Navigator.of(context);
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (!mounted) return;
                navigator.pop();
              });
            }

            return Center(child: _buildContent());
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    Widget content;
    switch (_btService.connectionState) {
      case BluetoothConnectionState.connected:
        content = _StatusIndicator(
          icon: Icons.check_circle,
          color: Colors.greenAccent,
          message: "Successfully Connected!",
        );
        break;
      case BluetoothConnectionState.connectionFailed:
        content = _StatusIndicator(
          icon: Icons.error,
          color: Colors.redAccent,
          message: "Connection Failed",
          buttonText: "Go Back",
          onButtonPressed: () => Navigator.of(context).pop(),
        );
        break;
      case BluetoothConnectionState.connecting:
      default:
        content = _StatusIndicator(
          icon: null,
          color: Colors.cyanAccent,
          message: "Connecting to ${widget.device.platformName}...",
          buttonText: "Cancel",
          onButtonPressed: () {
            _btService.disconnect();
            if (mounted) Navigator.of(context).pop();
          },
        );
        break;
    }
    return content;
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.icon,
    required this.color,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  final IconData? icon;
  final Color color;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null)
          Icon(icon, size: 80, color: color)
        else
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        const SizedBox(height: 32),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 48),
        if (buttonText != null)
          ElevatedButton(
            onPressed: onButtonPressed,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white70,
              minimumSize: const Size(150, 45),
            ),
            child: Text(buttonText!),
          ),
      ],
    );
  }
}
