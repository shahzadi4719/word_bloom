import 'package:flutter/services.dart' show rootBundle;

Future<Set<String>> loadWordList() async {
  final raw = await rootBundle.loadString('assets/words.txt');

  const blockedWords = <String>{
    'AAL', 'ABS', 'ADO', 'ADS', 'ALT', 'AMP',
    'BIO', 'BIS', 'BOT', 'CAD', 'CAL', 'CAM',
    'CIG', 'CIS', 'DEV', 'DOS', 'ECO', 'ETA',
    'FAB', 'FEM', 'GIF', 'GIS', 'GIT', 'INS',
    'MAC', 'MIC', 'MID', 'NTH', 'OPS', 'ORG',
    'PHI', 'PIC', 'PIX', 'PSI', 'REC', 'REF',
    'REG', 'REP', 'REV', 'RHO', 'SEC', 'SIG',
    'SIM', 'SKA', 'TIC', 'UMP', 'UNI', 'UPS',
    'UTE', 'VAC', 'VID', 'VIG',
  };

  final lettersOnly = RegExp(r'^[A-Z]+$');

  return raw
      .split(RegExp(r'\r?\n'))
      .map((word) => word.trim().toUpperCase())
      .where((word) =>
          word.length >= 3 &&
          word.length <= 8 &&
          lettersOnly.hasMatch(word) &&
          !blockedWords.contains(word))
      .toSet();
}