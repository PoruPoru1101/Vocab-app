import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/word.dart';

class WordRepository {
  WordRepository() : _uid = FirebaseAuth.instance.currentUser!.uid;

  final String _uid;

  /// エビングハウス曲線ベースの復習スケジュール (日数)。
  /// インデックスが reviewLevel に対応。
  static const _intervalDays = [1, 3, 7, 14, 30, 60];

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('words');

  Word _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Word(
      id: doc.id,
      english: data['english'] as String? ?? '',
      meanings: _parseMeanings(data),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      reviewLevel: (data['reviewLevel'] as int?) ?? 0,
      lastReviewedAt: (data['lastReviewedAt'] as Timestamp?)?.toDate(),
      nextReviewDue: (data['nextReviewDue'] as Timestamp?)?.toDate(),
    );
  }

  Map<PartOfSpeech, String> _parseMeanings(Map<String, dynamic> data) {
    final result = <PartOfSpeech, String>{};
    final raw = data['meanings'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! String || value.trim().isEmpty) continue;
        for (final pos in PartOfSpeech.values) {
          if (pos.name == entry.key) {
            result[pos] = value;
            break;
          }
        }
      }
    } else {
      // 旧フォーマット (meaning: String) を動詞欄に取り込む
      final old = data['meaning'];
      if (old is String && old.trim().isNotEmpty) {
        result[PartOfSpeech.verb] = old;
      }
    }
    return result;
  }

  Map<String, String> _serializeMeanings(Map<PartOfSpeech, String> meanings) {
    return {
      for (final entry in meanings.entries)
        if (entry.value.trim().isNotEmpty) entry.key.name: entry.value.trim(),
    };
  }

  Stream<List<Word>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(_fromDoc).toList());

  Future<List<Word>> loadAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<void> add({
    required String english,
    required Map<PartOfSpeech, String> meanings,
  }) async {
    final dueAt = DateTime.now().add(Duration(days: _intervalDays[0]));
    await _col.add({
      'english': english,
      'meanings': _serializeMeanings(meanings),
      'createdAt': FieldValue.serverTimestamp(),
      'reviewLevel': 0,
      'lastReviewedAt': null,
      'nextReviewDue': Timestamp.fromDate(dueAt),
    });
  }

  Future<void> update(Word word) async {
    await _col.doc(word.id).update({
      'english': word.english,
      'meanings': _serializeMeanings(word.meanings),
      'meaning': FieldValue.delete(),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// クイズの正解/不正解を反映して、次回復習日を更新する。
  /// 正解 → reviewLevel + 1 (上限あり)、間隔が伸びる。
  /// 不正解 → reviewLevel = 0 にリセットして翌日。
  Future<void> markReviewed(String wordId, {required bool correct}) async {
    final docRef = _col.doc(wordId);
    final snap = await docRef.get();
    final current = (snap.data()?['reviewLevel'] as int?) ?? 0;
    final newLevel = correct
        ? (current + 1).clamp(0, _intervalDays.length - 1)
        : 0;
    final dueAt = DateTime.now().add(Duration(days: _intervalDays[newLevel]));
    await docRef.update({
      'reviewLevel': newLevel,
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'nextReviewDue': Timestamp.fromDate(dueAt),
    });
  }
}
