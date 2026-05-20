import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../widgets/meaning_display.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.results});

  final List<QuizResult> results;

  int get _correctCount => results.where((r) => r.correct).length;
  int get _wrongCount => results.where((r) => !r.correct).length;

  @override
  Widget build(BuildContext context) {
    final correct = results.where((r) => r.correct).toList();
    final wrong = results.where((r) => !r.correct).toList();
    final total = results.length;
    final rate = total == 0 ? 0 : (_correctCount * 100 / total).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('結果'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '正答率 $rate%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '○ $_correctCount  /  × $_wrongCount  (全 $total 問)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (wrong.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.close,
              color: Colors.red,
              label: '不正解 (${wrong.length})',
            ),
            ...wrong.map((r) => _ResultTile(result: r)),
            const SizedBox(height: 16),
          ],
          if (correct.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.check,
              color: Colors.green,
              label: '正解 (${correct.length})',
            ),
            ...correct.map((r) => _ResultTile(result: r)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('ホーム', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('もう一度', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final w = result.question.word;
    final dirLabel = result.question.direction == QuizDirection.wordToMeaning
        ? '単語→意味'
        : '意味→単語';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          w.english,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MeaningsDisplay(meanings: w.meanings),
        ),
        isThreeLine: w.meanings.length >= 2,
        trailing: Text(
          dirLabel,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}
