import 'dart:math';

import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../models/word.dart';
import '../services/word_repository.dart';
import '../widgets/meaning_display.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.words,
    required this.mode,
    required this.questionCount,
  });

  final List<Word> words;
  final QuizMode mode;
  final int questionCount;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _random = Random();
  final _repo = WordRepository();

  late final List<QuizQuestion> _questions;
  final List<QuizResult> _results = [];

  int _index = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  List<QuizQuestion> _buildQuestions() {
    final shuffled = [...widget.words]..shuffle(_random);
    final picked = shuffled.take(widget.questionCount).toList();
    return picked.map((w) {
      final dir = switch (widget.mode) {
        QuizMode.wordToMeaning => QuizDirection.wordToMeaning,
        QuizMode.meaningToWord => QuizDirection.meaningToWord,
        QuizMode.random || QuizMode.review => _random.nextBool()
            ? QuizDirection.wordToMeaning
            : QuizDirection.meaningToWord,
      };
      return QuizQuestion(word: w, direction: dir);
    }).toList();
  }

  void _answer({required bool correct}) {
    final question = _questions[_index];
    _results.add(QuizResult(question: question, correct: correct));
    if (widget.mode == QuizMode.review) {
      _repo.markReviewed(question.word.id, correct: correct);
    }
    if (_index + 1 >= _questions.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _revealed = false;
      });
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(results: _results),
      ),
    );
  }

  int get _correctCount => _results.where((r) => r.correct).length;
  int get _wrongCount => _results.where((r) => !r.correct).length;

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('クイズ  ${_index + 1} / ${_questions.length}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '○ $_correctCount  / × $_wrongCount',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _index / _questions.length,
            ),
            const Spacer(),
            _PromptCard(question: question, revealed: _revealed),
            const Spacer(),
            if (!_revealed)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: Text(
                    '${question.answerLabel}を見る',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _answer(correct: false),
                        icon: const Icon(Icons.close),
                        label: const Text('不正解',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => _answer(correct: true),
                        icon: const Icon(Icons.check),
                        label:
                            const Text('正解', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.question, required this.revealed});

  final QuizQuestion question;
  final bool revealed;

  bool get _isPromptMeaning =>
      question.direction == QuizDirection.meaningToWord;

  Widget _buildSide(BuildContext context, {required bool isPrompt}) {
    final isMeaning =
        (isPrompt && _isPromptMeaning) || (!isPrompt && !_isPromptMeaning);
    final word = question.word;

    if (isMeaning) {
      return MeaningsDisplay(
        meanings: word.meanings,
        multiline: true,
        textStyle: TextStyle(
          fontSize: isPrompt ? 24 : 22,
          fontWeight: isPrompt ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }
    return Text(
      word.english,
      style: TextStyle(
        fontSize: isPrompt ? 32 : 28,
        fontWeight: isPrompt ? FontWeight.bold : FontWeight.normal,
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Text(
                question.promptLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildSide(context, isPrompt: true),
              if (revealed) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  question.answerLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSide(context, isPrompt: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
