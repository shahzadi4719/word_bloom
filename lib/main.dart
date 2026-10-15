import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'levels.dart';
import 'sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stopwatch = Stopwatch()..start();

  await initializeWordBank();
  debugPrint(
    'STARTUP TIME: Word bank = ${stopwatch.elapsedMilliseconds} ms',
  );

  final levelTimer = Stopwatch()..start();
  generateLevels();
  debugPrint(
    'STARTUP TIME: Generate levels = ${levelTimer.elapsedMilliseconds} ms',
  );

  final soundTimer = Stopwatch()..start();
  await SoundService.instance.ensureStarted();
  debugPrint(
    'STARTUP TIME: Sound service = ${soundTimer.elapsedMilliseconds} ms',
  );

  debugPrint(
    'STARTUP TIME: Total before runApp = ${stopwatch.elapsedMilliseconds} ms',
  );

  runApp(const WordBloomApp());
}

class WordBloomApp extends StatelessWidget {
  const WordBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Bloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins', useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
