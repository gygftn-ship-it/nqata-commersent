import 'package:flutter/material.dart';
import 'main.dart';
import 'icons.dart';

class BarData {
  final String label;
  final double value;
  const BarData(this.label, this.value);
}

/// Histogramme animé, sans dépendance externe.
class BarChartCard extends StatelessWidget {
  final String title;
  final List<BarData> data;
  final String Function(double)? fmt;
  final Widget? trailing;
  final String? footnote;
  final double height;
  final int labelEvery;
  const BarChartCard({super.key, required this.title, required this.data, this.fmt, this.trailing, this.footnote, this.height = 120, this.labelEvery = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = data.fold<double>(0, (m, d) => d.value > m ? d.value : m);
    final empty = maxV == 0;
    final showValues = data.length <= 12;
    String f(double v) => fmt != null ? fmt!(v) : v.round().toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 14),
        if (empty)
          SizedBox(height: height, child: Center(child: Text(tr('Pas encore de données', 'لا بيانات بعد'), style: const TextStyle(color: kMuted))))
        else
          SizedBox(
            height: height + 38,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    SizedBox(
                      height: 14,
                      child: showValues && data[i].value > 0
                          ? OverflowBox(maxWidth: 60, child: Text(f(data[i].value), softWrap: false, style: const TextStyle(fontSize: 10)))
                          : null,
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data[i].value <= 0 ? 0 : (data[i].value / maxV * height).clamp(3.0, height)),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, h, __) => Container(
                        height: h,
                        margin: EdgeInsets.symmetric(horizontal: data.length > 20 ? 1 : 3),
                        decoration: BoxDecoration(
                          color: data[i].value == maxV ? cs.onSurface : cs.outline,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      child: i % labelEvery == 0
                          ? OverflowBox(maxWidth: 52, child: Text(data[i].label, softWrap: false, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kMuted)))
                          : null,
                    ),
                  ]),
                ),
            ]),
          ),
        if (footnote != null && !empty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(footnote!, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

/// Carte d'un indicateur : valeur, libellé et évolution par rapport à la période précédente.
class KpiCard extends StatelessWidget {
  final Object icon;
  final String value, label;
  final double? delta; // en %, null = pas de comparaison
  final String? hint;
  const KpiCard({super.key, required this.icon, required this.value, required this.label, this.delta, this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          ic(icon, size: 22, color: cs.onSurfaceVariant),
          const Spacer(),
          if (delta != null) _Delta(delta!),
        ]),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        Text(hint == null ? label : '$label · $hint', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _Delta extends StatelessWidget {
  final double v;
  const _Delta(this.v);
  @override
  Widget build(BuildContext context) {
    final up = v >= 0;
    final c = v.abs() < 0.5 ? kMuted : (up ? kOk : kDanger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text('${v.abs() < 0.5 ? '' : (up ? '▲ ' : '▼ ')}${v.abs().round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

/// Barre empilée (répartition en segments).
class SegmentBar extends StatelessWidget {
  final List<(String, int, Color)> parts;
  const SegmentBar({super.key, required this.parts});
  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    if (total == 0) return Text(tr('Pas encore de données', 'لا بيانات بعد'), style: const TextStyle(color: kMuted));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          for (final p in parts)
            if (p.$2 > 0) Expanded(flex: p.$2, child: Container(height: 14, color: p.$3)),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final p in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${p.$1} : ${p.$2} (${(p.$2 * 100 / total).round()}%)', style: const TextStyle(fontSize: 12)),
          ]),
      ]),
    ]);
  }
}
