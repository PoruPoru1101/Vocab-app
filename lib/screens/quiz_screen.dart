import 'dart:async';
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

  /// 3 択モードで選んだ答え (next問題遷移までの一時保持)
  Word? _selectedChoice;
  bool _mcAnswered = false;

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
        QuizMode.wordToMeaning ||
        QuizMode.mcWordToMeaning =>
          QuizDirection.wordToMeaning,
        QuizMode.meaningToWord ||
        QuizMode.mcMeaningToWord =>
          QuizDirection.meaningToWord,
        QuizMode.random || QuizMode.review => _random.nextBool()
            ? QuizDirection.wordToMeaning
            : QuizDirection.meaningToWord,
      };
      final choices = widget.mode.isMultipleChoice
          ? _generateChoices(w, widget.words)
          : null;
      return QuizQuestion(word: w, direction: dir, choices: choices);
    }).toList();
  }

  List<Word> _generateChoices(Word correct, List<Word> pool) {
    final others = pool.where((w) => w.id != correct.id).toList()
      ..shuffle(_random);
    final numDistractors = (pool.length - 1).clamp(0, 2);
    final distractors = others.take(numDistractors).toList();
    final all = [correct, ...distractors]..shuffle(_random);
    return all;
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
        _selectedChoice = null;
        _mcAnswered = false;
      });
    }
  }

  Future<void> _selectChoice(Word choice) async {
    if (_mcAnswered) return;
    final question = _questions[_index];
    final correct = choice.id == question.word.id;
    setState(() {
      _selectedChoice = choice;
      _mcAnswered = true;
    });
    _results.add(QuizResult(question: question, correct: correct));
    if (widget.mode == QuizMode.review) {
      _repo.markReviewed(question.word.id, correct: correct);
    }
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _revealed = false;
        _selectedChoice = null;
        _mcAnswered = false;
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
        child: question.isMultipleChoice
            ? _buildMCBody(context, question)
            : _buildFlashcardBody(context, question),
      ),
    );
  }

  Widget _buildFlashcardBody(BuildContext context, QuizQuestion question) {
    return Column(
      children: [
        LinearProgressIndicator(value: _index / _questions.length),
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
                    label: const Text('不正解', style: TextStyle(fontSize: 18)),
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
                    label: const Text('正解', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMCBody(BuildContext context, QuizQuestion question) {
    return Column(
      children: [
        LinearProgressIndicator(value: _index / _questions.length),
        const SizedBox(height: 16),
        _PromptCard(question: question, revealed: false),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              for (final choice in question.choices!) ...[
                _MCChoiceButton(
                  choice: choice,
                  question: question,
                  isSelected: _selectedChoice?.id == choice.id,
                  isCorrect: choice.id == question.word.id,
                  answered: _mcAnswered,
                  onTap: () => _selectChoice(choice),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MCChoiceButton extends StatelessWidget {
  const _MCChoiceButton({
    required this.choice,
    required this.question,
    required this.isSelected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final Word choice;
  final QuizQuestion question;
  final bool isSelected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color borderColor;
    Color textColor;
    if (!answered) {
      bgColor = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outline;
      textColor = theme.colorScheme.onSurface;
    } else if (isCorrect) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green;
      textColor = Colors.green.shade900;
    } else if (isSelected) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red;
      textColor = Colors.red.shade900;
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      borderColor = theme.colorScheme.outlineVariant;
      textColor = theme.hintColor;
    }

    final answerIsEnglish =
        question.direction == QuizDirection.meaningToWord;
    final subColor = answered ? textColor.withValues(alpha: 0.75) : textColor;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // メインの答え側
                    answerIsEnglish
                        ? Text(
                            choice.english,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          )
                        : MeaningsDisplay(
                            meanings: choice.meanings,
                            textStyle: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                    // 回答後はもう一方の情報も表示
                    if (answered) ...[
                      const SizedBox(height: 6),
                      answerIsEnglish
                          ? MeaningsDisplay(
                              meanings: choice.meanings,
                              textStyle: TextStyle(
                                fontSize: 13,
                                color: subColor,
                              ),
                            )
                          : Text(
                              choice.english,
                              style: TextStyle(
                                fontSize: 14,
                                color: subColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ],
                  ],
                ),
              ),
              if (answered && isCorrect)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle,
                      color: Colors.green, size: 28),
                ),
              if (answered && isSelected && !isCorrect)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child:
                      Icon(Icons.cancel, color: Colors.red, size: 28),
                ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
