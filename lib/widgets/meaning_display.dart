import 'package:flutter/material.dart';

import '../models/word.dart';

/// 品詞ラベル付きで意味を表示するウィジェット。
/// `multiline = true` で各品詞ごとに改行、false で横に並べる (折り返しあり)。
class MeaningsDisplay extends StatelessWidget {
  const MeaningsDisplay({
    super.key,
    required this.meanings,
    this.multiline = false,
    this.textStyle,
    this.alignment = WrapAlignment.start,
  });

  final Map<PartOfSpeech, String> meanings;
  final bool multiline;
  final TextStyle? textStyle;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final orderedPos = PartOfSpeech.values
        .where((p) => (meanings[p] ?? '').trim().isNotEmpty)
        .toList();
    if (orderedPos.isEmpty) return const SizedBox.shrink();

    final style = textStyle ?? DefaultTextStyle.of(context).style;

    if (multiline) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < orderedPos.length; i++) ...[
            if (i > 0) SizedBox(height: (style.fontSize ?? 14) * 0.3),
            _MeaningRow(
              pos: orderedPos[i],
              text: meanings[orderedPos[i]]!,
              textStyle: style,
            ),
          ],
        ],
      );
    }

    return Wrap(
      alignment: alignment,
      spacing: (style.fontSize ?? 14) * 0.5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final pos in orderedPos)
          _MeaningRow(
            pos: pos,
            text: meanings[pos]!,
            textStyle: style,
          ),
      ],
    );
  }
}

class _MeaningRow extends StatelessWidget {
  const _MeaningRow({
    required this.pos,
    required this.text,
    required this.textStyle,
  });

  final PartOfSpeech pos;
  final String text;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final size = textStyle.fontSize ?? 14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosBadge(pos: pos, fontSize: (size * 0.7).clamp(9, 16)),
        SizedBox(width: size * 0.3),
        Flexible(child: Text(text, style: textStyle)),
      ],
    );
  }
}

/// 「動」「名」などの品詞ラベルを枠付きで表示するチップ。
class PosBadge extends StatelessWidget {
  const PosBadge({super.key, required this.pos, this.fontSize = 11});

  final PartOfSpeech pos;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.45,
        vertical: fontSize * 0.15,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pos.shortLabel,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}
