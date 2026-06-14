import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/word.dart';
import '../services/word_repository.dart';
import '../widgets/meaning_display.dart';

typedef _WordEditorResult = ({
  String english,
  Map<PartOfSpeech, String> meanings,
});

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key, this.openEditorOnLoad = false});

  /// 画面表示時に単語追加ダイアログを自動で開くかどうか
  final bool openEditorOnLoad;

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final _repo = WordRepository();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _columns = 1;

  IconData _iconForColumns(int n) {
    switch (n) {
      case 1:
        return Icons.view_agenda_outlined;
      case 2:
        return Icons.view_column_outlined;
      case 3:
        return Icons.view_module_outlined;
      case 4:
        return Icons.grid_view_outlined;
      default:
        return Icons.view_agenda_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.openEditorOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Word> _filter(List<Word> words) {
    if (_searchQuery.isEmpty) return words;
    final q = _searchQuery.toLowerCase().trim();
    return words.where((w) {
      if (w.english.toLowerCase().contains(q)) return true;
      for (final m in w.meanings.values) {
        if (m.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _openEditor({Word? existing}) async {
    final result = await showDialog<_WordEditorResult>(
      context: context,
      builder: (_) => _WordEditorDialog(initial: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await _repo.add(english: result.english, meanings: result.meanings);
    } else {
      await _repo.update(existing.copyWith(
        english: result.english,
        meanings: result.meanings,
      ));
    }
  }

  Future<void> _confirmDelete(Word word) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか?'),
        content: Text('"${word.english}" を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.delete(word.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Word>>(
          stream: _repo.watchAll(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Text('単語一覧 ($count 個)');
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<int>(
            icon: Icon(_iconForColumns(_columns)),
            tooltip: '表示列数',
            onSelected: (v) => setState(() => _columns = v),
            itemBuilder: (_) => [1, 2, 3, 4]
                .map(
                  (n) => PopupMenuItem<int>(
                    value: n,
                    child: Row(
                      children: [
                        Icon(_iconForColumns(n), size: 18),
                        const SizedBox(width: 12),
                        Text('$n 列'),
                        if (n == _columns) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check, size: 16),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN): _openEditor,
        },
        child: Focus(
          autofocus: true,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _columns == 1 ? 900 : double.infinity,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '単語または意味で検索',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Word>>(
                      stream: _repo.watchAll(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('エラー: ${snapshot.error}'),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final allWords = snapshot.data!;
                        if (allWords.isEmpty) {
                          return const Center(
                            child: Text(
                              '単語がまだ登録されていません。\n右下の + から追加してください。',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final words = _filter(allWords);
                        if (words.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '"$_searchQuery" にヒットする単語はありません',
                                style: TextStyle(
                                    color: Theme.of(context).hintColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return LayoutBuilder(
                          builder: (context, layoutConstraints) {
                            const spacing = 8.0;
                            const horizontalPadding = 8.0;
                            final cols = _columns;
                            final available = layoutConstraints.maxWidth -
                                horizontalPadding * 2;
                            final cardWidth =
                                (available - spacing * (cols - 1)) / cols;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                  horizontalPadding, 4, horizontalPadding, 80),
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                alignment: WrapAlignment.start,
                                children: [
                                  for (final w in words)
                                    SizedBox(
                                      width: cardWidth,
                                      child: _WordCard(
                                        word: w,
                                        onTap: () => _openEditor(existing: w),
                                        onDelete: () => _confirmDelete(w),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '新規追加 (N)',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.onTap,
    required this.onDelete,
  });

  final Word word;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _fmtDate(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    final isDue = word.isDueForReview;
    final dueColor = isDue ? theme.colorScheme.tertiary : hintColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: 英単語 + 削除ボタン
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      word.english,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: hintColor),
                    onPressed: onDelete,
                    tooltip: '削除',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 2: 意味 (品詞付き)
              MeaningsDisplay(
                meanings: word.meanings,
                textStyle: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              // Row 3: メタ情報 (復習Lv / 次回 / 追加日)
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _MetaItem(
                    icon: Icons.school_outlined,
                    label: 'Lv.${word.reviewLevel}',
                    color: hintColor,
                  ),
                  if (word.nextReviewDue != null)
                    _MetaItem(
                      icon: Icons.event_repeat_outlined,
                      label: isDue
                          ? '復習可'
                          : '次回 ${_fmtDate(word.nextReviewDue!)}',
                      color: dueColor,
                      bold: isDue,
                    ),
                  if (word.createdAt != null)
                    _MetaItem(
                      icon: Icons.calendar_today_outlined,
                      label: '追加 ${_fmtDate(word.createdAt!)}',
                      color: hintColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.color,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _WordEditorDialog extends StatefulWidget {
  const _WordEditorDialog({this.initial});

  final Word? initial;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _englishCtrl;
  late final Map<PartOfSpeech, TextEditingController> _meaningCtrls;
  late final FocusNode _englishFocus;
  late final Map<PartOfSpeech, FocusNode> _meaningFocuses;
  late final List<FocusNode> _focusOrder;
  final _formKey = GlobalKey<FormState>();
  String? _meaningsError;

  @override
  void initState() {
    super.initState();
    _englishCtrl = TextEditingController(text: widget.initial?.english ?? '');
    _englishFocus = _makeNavFocusNode();
    _meaningCtrls = {
      for (final p in PartOfSpeech.values)
        p: TextEditingController(text: widget.initial?.meanings[p] ?? ''),
    };
    _meaningFocuses = {
      for (final p in PartOfSpeech.values) p: _makeNavFocusNode(),
    };
    _focusOrder = [_englishFocus, ..._meaningFocuses.values];
  }

  /// 上下矢印キーで次/前のフィールドへ移動できる FocusNode を生成。
  FocusNode _makeNavFocusNode() {
    return FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _moveFocus(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _moveFocus(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  void _moveFocus(int delta) {
    final current = _focusOrder.indexWhere((f) => f.hasFocus);
    if (current == -1) return;
    final next = current + delta;
    if (next < 0 || next >= _focusOrder.length) return;
    _focusOrder[next].requestFocus();
  }

  @override
  void dispose() {
    _englishCtrl.dispose();
    _englishFocus.dispose();
    for (final c in _meaningCtrls.values) {
      c.dispose();
    }
    for (final f in _meaningFocuses.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final meanings = <PartOfSpeech, String>{};
    for (final entry in _meaningCtrls.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        meanings[entry.key] = text;
      }
    }

    if (meanings.isEmpty) {
      setState(() => _meaningsError = '少なくとも 1 つの品詞に意味を入力してください');
      return;
    }

    Navigator.pop(
      context,
      (
        english: _englishCtrl.text.trim(),
        meanings: meanings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.initial == null ? '単語を追加' : '単語を編集'),
          const SizedBox(height: 2),
          Text(
            '↑↓ で移動 / Enter で保存',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _englishCtrl,
                focusNode: _englishFocus,
                onFieldSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '英単語'),
                autofocus: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '入力してください' : null,
              ),
              const SizedBox(height: 16),
              Text(
                '意味 (該当する品詞のみ入力)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              for (final pos in PartOfSpeech.values) ...[
                TextFormField(
                  controller: _meaningCtrls[pos],
                  focusNode: _meaningFocuses[pos],
                  onFieldSubmitted: (_) => _submit(),
                  textInputAction: pos == PartOfSpeech.values.last
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: pos.label,
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_meaningsError != null) {
                      setState(() => _meaningsError = null);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (_meaningsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _meaningsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
