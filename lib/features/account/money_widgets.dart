import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

/// One bar segment: a value and its colour.
typedef BarPart = ({double value, Color color});

/// Monthly stacked bars (oldest → newest). Hover / tap a bar to see its numbers.
class MonthBars extends StatefulWidget {
  const MonthBars({super.key, required this.months, required this.parts, required this.legend, this.height = 170});

  final List<DateTime> months;

  /// For each month, the stacked parts from the bottom up.
  final List<List<BarPart>> parts;
  final List<({String label, Color color})> legend;
  final double height;

  @override
  State<MonthBars> createState() => _MonthBarsState();
}

class _MonthBarsState extends State<MonthBars> {
  int? _selected;

  static const _monthLetters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = [for (final p in widget.parts) p.fold<double>(0, (a, b) => a + b.value)];
    final max = totals.fold<double>(0, (a, b) => b > a ? b : a);
    final selected = _selected ?? (widget.months.isEmpty ? null : widget.months.length - 1);
    final wide = MediaQuery.of(context).size.width > 600;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // What the highlighted month adds up to
      if (selected != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(monthName(widget.months[selected]), style: theme.textTheme.titleSmall),
            for (var i = 0; i < widget.legend.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.legend[i].color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('${widget.legend[i].label} ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(money(widget.parts[selected].length > i ? widget.parts[selected][i].value : 0),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              ]),
          ]),
        ),
      SizedBox(
        height: widget.height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var m = 0; m < widget.months.length; m++)
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _selected = m),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = m),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 6 : 3),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: selected == m ? 1 : 0.55,
                            child: _Bar(parts: widget.parts[m], max: max),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wide ? _monthNames[widget.months[m].month - 1] : _monthLetters[widget.months[m].month - 1],
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected == m ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          fontWeight: selected == m ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.parts, required this.max});

  final List<BarPart> parts;
  final double max;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final full = constraints.maxHeight;
      final total = parts.fold<double>(0, (a, b) => a + b.value);
      if (total <= 0 || max <= 0) {
        return Container(
          height: 3,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
        );
      }
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in parts.reversed)
            if (p.value > 0) Container(height: (p.value / max) * full, color: p.color),
        ]),
      );
    });
  }
}

/// A gradient headline card: the number that matters most, plus a few smaller ones.
class MoneyHero extends StatelessWidget {
  const MoneyHero({super.key, required this.label, required this.amount, this.caption, this.stats = const []});

  final String label;
  final double amount;
  final String? caption;
  final List<({String label, String value})> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.brand, AppColors.brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(money(amount),
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1)),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 28, runSpacing: 14, children: [
            for (final s in stats)
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                const SizedBox(height: 2),
                Text(s.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
          ]),
        ],
      ]),
    );
  }
}

/// "Families paid … − commission … = your earnings": a small ledger with a bold total line.
class Ledger extends StatelessWidget {
  const Ledger({super.key, required this.rows, required this.totalLabel, required this.total});

  final List<({String label, double amount, String? note})> rows;
  final String totalLabel;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.label),
                if (r.note != null)
                  Text(r.note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            Text(signedMoney(r.amount),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: r.amount < 0 ? theme.colorScheme.error : theme.colorScheme.onSurface)),
          ]),
        ),
      const Divider(height: 20),
      Row(children: [
        Expanded(child: Text(totalLabel, style: theme.textTheme.titleMedium)),
        Text(money(total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    ]);
  }
}

String signedMoney(double amount) => amount < 0 ? '−${money(-amount)}' : money(amount);
