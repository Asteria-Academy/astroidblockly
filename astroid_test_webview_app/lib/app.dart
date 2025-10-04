import 'package:flutter/material.dart';
import 'screens/splash_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Astroid Blockly',
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Poppins'),
      home: const SplashGate(), // <-- start di splash
    );
  }
}
