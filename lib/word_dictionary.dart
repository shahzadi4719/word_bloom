import 'package:flutter/services.dart' show rootBundle;

Future<Set<String>> loadWordList() async {
  final String raw = await rootBundle.loadString('assets/words.txt');
  final RegExp letters = RegExp(r'^[A-Z]+$');
  return raw
      .split('\n')
      .map((w) => w.trim().toUpperCase())
      .where((w) => w.length >= 3 && w.length <= 8 && letters.hasMatch(w))
      .toSet();
}