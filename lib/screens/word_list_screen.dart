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
        title: const Text('単語一覧'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN): _openEditor,
        },
        child: Focus(
          autofocus: true,
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
                  return const Center(child: CircularProgressIndicator());
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
                        style: TextStyle(color: Theme.of(context).hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: words.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final w = words[index];
                    return ListTile(
                      title: Text(
                        w.english,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: MeaningsDisplay(meanings: w.meanings),
                      ),
                      isThreeLine: w.meanings.length >= 2,
                      onTap: () => _openEditor(existing: w),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(w),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '新規追加 (N)',
        child: const Icon(Icons.add),
      ),
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
  final _formKey = GlobalKey<FormState>();
  String? _meaningsError;

  @override
  void initState() {
    super.initState();
    _englishCtrl = TextEditingController(text: widget.initial?.english ?? '');
    _meaningCtrls = {
      for (final p in PartOfSpeech.values)
        p: TextEditingController(text: widget.initial?.meanings[p] ?? ''),
    };
  }

  @override
  void dispose() {
    _englishCtrl.dispose();
    for (final c in _meaningCtrls.values) {
      c.dispose();
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
      title: Text(widget.initial == null ? '単語を追加' : '単語を編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _englishCtrl,
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
