import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'levels.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeWordBank();
  generateLevels();

  runApp(const WordBloomApp());
}

class WordBloomApp extends StatelessWidget {
  const WordBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Bloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}