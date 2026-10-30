/// Stable names are also used for separate saved progress.
enum GameMode { wordBloom, colorMatch, letterMatch }

extension GameModeDetails on GameMode {
  String get title => switch (this) {
    GameMode.wordBloom => 'Word Bloom',
    GameMode.colorMatch => 'Color Bloom',
    GameMode.letterMatch => 'Letter Bloom',
  };
  String get description => switch (this) {
    GameMode.wordBloom => 'Connect letters to complete words',
    GameMode.colorMatch => 'Match 3 or more bubbles of the same color',
    GameMode.letterMatch => 'Match 3 or more bubbles with the same letter',
  };
  bool get isWordMode => this == GameMode.wordBloom;
  bool get showLetters => this != GameMode.colorMatch;
}
