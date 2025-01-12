import 'package:flutter/material.dart';
import 'package:macos_dock/dock.dart';

final class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Dock(
          items: const [
            Icons.person,
            Icons.message,
            Icons.call,
            Icons.camera,
            Icons.photo,
          ],
          builder: (e) => Container(
            constraints: const BoxConstraints(minWidth: 48),
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.primaries[e.hashCode % Colors.primaries.length],
            ),
            child: Center(child: Icon(e, color: Colors.white)),
          ),
        ),
      ),
    ),
  );
}