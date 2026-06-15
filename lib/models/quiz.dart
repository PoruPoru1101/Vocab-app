import 'word.dart';

enum QuizMode {
  wordToMeaning('単語 → 意味'),
  meaningToWord('意味 → 単語'),
  random('ランダム'),
  review('復習モード (忘却曲線)'),
  mcWordToMeaning('3 択: 単語 → 意味'),
  mcMeaningToWord('3 択: 意味 → 単語');

  const QuizMode(this.label);
  final String label;

  bool get isMultipleChoice =>
      this == QuizMode.mcWordToMeaning || this == QuizMode.mcMeaningToWord;
}

enum QuizDirection { wordToMeaning, meaningToWord }

class QuizQuestion {
  final Word word;
  final QuizDirection direction;

  /// 3 択モード時のシャッフル済み選択肢 (正解を含む)。
  /// フラッシュカードモードでは null。
  final List<Word>? choices;

  QuizQuestion({
    required this.word,
    required this.direction,
    this.choices,
  });

  bool get isMultipleChoice => choices != null;

  String get prompt => direction == QuizDirection.wordToMeaning
      ? word.english
      : word.meaningMultiline;
  String get answer => direction == QuizDirection.wordToMeaning
      ? word.meaningMultiline
      : word.english;
  String get promptLabel =>
      direction == QuizDirection.wordToMeaning ? '英単語' : '意味';
  String get answerLabel =>
      direction == QuizDirection.wordToMeaning ? '意味' : '英単語';
}

class QuizResult {
  final QuizQuestion question;
  final bool correct;

  QuizResult({required this.question, required this.correct});
}
