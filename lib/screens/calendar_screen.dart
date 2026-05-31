import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/word.dart';
import '../services/word_repository.dart';
import '../widgets/meaning_display.dart';
import 'quiz_setup_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = WordRepository();
  StreamSubscription<List<Word>>? _wordsSub;

  Map<DateTime, List<Word>> _wordsByDay = {};
  bool _loading = true;

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = _normalize(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
    _wordsSub = _repo.watchAll().listen((words) {
      if (!mounted) return;
      final map = <DateTime, List<Word>>{};
      for (final w in words) {
        if (w.createdAt == null) continue;
        final key = _normalize(w.createdAt!);
        map.putIfAbsent(key, () => []).add(w);
      }
      setState(() {
        _wordsByDay = map;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _wordsSub?.cancel();
    super.dispose();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Word> _wordsForDay(DateTime day) {
    return _wordsByDay[_normalize(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習カレンダー'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar<Word>(
                  locale: 'ja_JP',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = _normalize(selected);
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    _focusedDay = focused;
                  },
                  eventLoader: _wordsForDay,
                  availableCalendarFormats: const {
                    CalendarFormat.month: '月',
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildDayList()),
              ],
            ),
    );
  }

  Widget _buildDayList() {
    final words = _wordsForDay(_selectedDay);
    final dateLabel =
        '${_selectedDay.year}/${_selectedDay.month}/${_selectedDay.day}';

    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$dateLabel に追加した単語はありません',
            style: TextStyle(color: Theme.of(context).hintColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$dateLabel に追加 (${words.length} 個)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizSetupScreen(
                        presetWords: words,
                        presetTitle: '$dateLabel に追加した単語',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.quiz, size: 18),
                label: const Text('この日の単語でクイズ'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
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
                trailing: w.reviewLevel > 0
                    ? Chip(
                        label: Text('Lv.${w.reviewLevel}'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
