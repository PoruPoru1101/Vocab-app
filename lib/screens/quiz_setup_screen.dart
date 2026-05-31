import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quiz.dart';
import '../models/word.dart';
import '../services/word_repository.dart';
import 'quiz_screen.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({
    super.key,
    this.presetWords,
    this.presetTitle,
  });

  /// 指定された単語リストでクイズを実行する場合に渡す
  /// (例: カレンダーから「この日の単語」を出題する場合)
  final List<Word>? presetWords;

  /// プリセット表示時のサブタイトル (例: "2026/5/15 に追加した単語")
  final String? presetTitle;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final _repo = WordRepository();
  final _countController = TextEditingController(text: '10');
  StreamSubscription<List<Word>>? _wordsSub;

  List<Word> _words = [];
  List<Word> _dueWords = [];
  bool _loading = true;

  QuizMode _mode = QuizMode.wordToMeaning;
  String? _countError;

  bool get _isPreset => widget.presetWords != null;

  @override
  void initState() {
    super.initState();
    _countController.addListener(_validate);
    if (_isPreset) {
      _words = widget.presetWords!;
      _dueWords = _words.where((w) => w.isDueForReview).toList();
      _loading = false;
      _resetCountForMode();
      _validate();
    } else {
      _wordsSub = _repo.watchAll().listen((words) {
        if (!mounted) return;
        setState(() {
          _words = words;
          _dueWords = words.where((w) => w.isDueForReview).toList();
          _loading = false;
          _resetCountForMode();
          _validate();
        });
      });
    }
  }

  @override
  void dispose() {
    _wordsSub?.cancel();
    _countController.dispose();
    super.dispose();
  }

  /// モード切替時に出題数の初期値を新しい上限内に調整。
  void _resetCountForMode() {
    final max = _maxCount;
    if (max == 0) {
      _countController.text = '0';
      return;
    }
    final current = int.tryParse(_countController.text) ?? 0;
    if (current < 1 || current > max) {
      final initial = max < 10 ? max : 10;
      _countController.text = initial.toString();
    }
  }

  List<Word> get _selectedWords =>
      _mode == QuizMode.review ? _dueWords : _words;

  int get _maxCount => _selectedWords.length;

  int? get _parsedCount => int.tryParse(_countController.text);

  bool get _isValid =>
      _countError == null && _parsedCount != null && _maxCount > 0;

  void _validate() {
    final text = _countController.text;
    String? error;
    if (_maxCount == 0 && _mode == QuizMode.review) {
      error = '復習対象の単語が現在ありません';
    } else if (_maxCount == 0) {
      error = '単語が登録されていません';
    } else if (text.isEmpty) {
      error = '出題数を入力してください';
    } else {
      final n = int.tryParse(text);
      if (n == null) {
        error = '数字で入力してください';
      } else if (n < 1) {
        error = '1問以上を指定してください';
      } else if (n > _maxCount) {
        error = '上限 ($_maxCount 個) より多くは指定できません';
      }
    }
    if (error != _countError) {
      setState(() => _countError = error);
    }
  }

  void _setAllQuestions() {
    _countController.text = _maxCount.toString();
    _countController.selection = TextSelection.fromPosition(
      TextPosition(offset: _countController.text.length),
    );
  }

  void _onModeChanged(QuizMode? v) {
    if (v == null) return;
    setState(() {
      _mode = v;
      _resetCountForMode();
      _validate();
    });
  }

  void _start() {
    if (!_isValid) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: _selectedWords,
          mode: _mode,
          questionCount: _parsedCount!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('クイズ設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '単語が登録されていません。\nまず「単語一覧 / 追加」から登録してください。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildSetup(context),
    );
  }

  Widget _buildSetup(BuildContext context) {
    final isAllSelected = _parsedCount == _maxCount && _maxCount > 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isPreset && widget.presetTitle != null) ...[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(widget.presetTitle!),
              subtitle: Text('${_words.length} 個の単語が対象'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('出題モード', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: RadioGroup<QuizMode>(
            groupValue: _mode,
            onChanged: _onModeChanged,
            child: Column(
              children: QuizMode.values.map((mode) {
                return RadioListTile<QuizMode>(
                  title: Text(mode.label),
                  subtitle: mode == QuizMode.review
                      ? Text('復習対象: ${_dueWords.length} 個')
                      : null,
                  value: mode,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('出題数', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          _mode == QuizMode.review
              ? '復習対象: $_maxCount 個'
              : '登録単語: $_maxCount 個',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    enabled: _maxCount > 0,
                    decoration: InputDecoration(
                      labelText: '出題数',
                      suffixText: '問',
                      errorText: _countError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ChoiceChip(
                    label: Text('全問 ($_maxCount)'),
                    selected: isAllSelected,
                    onSelected:
                        _maxCount > 0 ? (_) => _setAllQuestions() : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _isValid ? _start : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('スタート', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
