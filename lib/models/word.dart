enum PartOfSpeech {
  verb('動詞', '動'),
  noun('名詞', '名'),
  adjective('形容詞', '形'),
  adverb('副詞', '副'),
  preposition('前置詞', '前'),
  conjunction('接続詞', '接');

  const PartOfSpeech(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

class Word {
  final String id;
  final String english;
  final Map<PartOfSpeech, String> meanings;
  final DateTime? createdAt;
  final int reviewLevel;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewDue;

  Word({
    required this.id,
    required this.english,
    required this.meanings,
    this.createdAt,
    this.reviewLevel = 0,
    this.lastReviewedAt,
    this.nextReviewDue,
  });

  bool get isDueForReview {
    if (nextReviewDue == null) return true;
    return !nextReviewDue!.isAfter(DateTime.now());
  }

  /// 「動 研究する  /  名 研究」のような単一行表示用。
  String get meaningInline => _formatMeanings('  /  ');

  /// 「動 研究する\n名 研究」のような複数行表示用。
  String get meaningMultiline => _formatMeanings('\n');

  String _formatMeanings(String separator) {
    if (meanings.isEmpty) return '';
    return PartOfSpeech.values
        .where((p) => (meanings[p] ?? '').trim().isNotEmpty)
        .map((p) => '${p.shortLabel} ${meanings[p]}')
        .join(separator);
  }

  Word copyWith({String? english, Map<PartOfSpeech, String>? meanings}) {
    return Word(
      id: id,
      english: english ?? this.english,
      meanings: meanings ?? this.meanings,
      createdAt: createdAt,
      reviewLevel: reviewLevel,
      lastReviewedAt: lastReviewedAt,
      nextReviewDue: nextReviewDue,
    );
  }
}
