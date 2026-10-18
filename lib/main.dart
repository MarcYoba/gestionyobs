import 'package:flutter/material.dart';

import 'startup_page.dart';

void main() {
  runApp(const MonApp());
}

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOBSTIE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StartupPage(),
      // home: const LoginPage(),
      //home: const ConfigTestPage(),
      //home: const ConfigPage(),
    );
  }
}
