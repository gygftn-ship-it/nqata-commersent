import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main.dart';
import 'icons.dart';

class BarData {
  final String label;
  final double value;
  final String? detail; // libellé complet affiché quand on touche la barre
  const BarData(this.label, this.value, [this.detail]);
}

/// Histogramme animé, sans dépendance externe.
/// Toucher une barre affiche son détail ; [showAverage] trace la ligne de moyenne.
class BarChartCard extends StatefulWidget {
  final String title;
  final List<BarData> data;
  final String Function(double)? fmt;
  final Widget? trailing;
  final String? footnote;
  final String? unit;
  final double height;
  final int labelEvery;
  final bool showAverage;
  const BarChartCard({super.key, required this.title, required this.data, this.fmt, this.trailing, this.footnote, this.unit, this.height = 120, this.labelEvery = 1, this.showAverage = false});

  @override
  State<BarChartCard> createState() => _BarChartCardState();
}

class _BarChartCardState extends State<BarChartCard> {
  int? sel;

  @override
  void didUpdateWidget(BarChartCard old) {
    super.didUpdateWidget(old);
    if (old.data.length != widget.data.length) sel = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.data, height = widget.height;
    final maxV = data.fold<double>(0, (m, d) => d.value > m ? d.value : m);
    final empty = maxV == 0;
    final showValues = data.length <= 12;
    final avg = data.isEmpty ? 0.0 : data.fold<double>(0, (a, d) => a + d.value) / data.length;
    String f(double v) => widget.fmt != null ? widget.fmt!(v) : v.round().toString();
    // La moyenne garde une décimale quand elle est petite (0,4 / 3,5 ...).
    String favg(double v) => widget.fmt != null ? widget.fmt!(v) : (v < 10 ? v.toStringAsFixed(1).replaceAll('.', ',') : v.round().toString());
    final s = sel;
    final String? selText = (s != null && s < data.length) ? '${data[s].detail ?? data[s].label} : ${f(data[s].value)}${widget.unit == null ? '' : ' ${widget.unit}'}' : null;
    final note = selText ?? widget.footnote;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          if (widget.trailing != null) widget.trailing!,
        ]),
        const SizedBox(height: 14),
        if (empty)
          SizedBox(height: height, child: Center(child: Text(tr('Pas encore de données', 'لا بيانات بعد'), style: const TextStyle(color: kMuted))))
        else
          SizedBox(
            height: height + 38,
            child: Stack(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < data.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => sel = sel == i ? null : i),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        SizedBox(
                          height: 14,
                          child: (showValues && data[i].value > 0) || (sel == i && data[i].value > 0)
                              ? OverflowBox(maxWidth: 60, child: Text(f(data[i].value), softWrap: false, style: TextStyle(fontSize: 10, fontWeight: sel == i ? FontWeight.w800 : FontWeight.w400)))
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
                              color: sel == i ? kAccent : (data[i].value == maxV ? cs.onSurface : cs.outline),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 16,
                          child: i % widget.labelEvery == 0
                              ? OverflowBox(maxWidth: 52, child: Text(data[i].label, softWrap: false, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kMuted)))
                              : null,
                        ),
                      ]),
                    ),
                  ),
              ]),
              // La base des barres est à 20 px du bas (4 + 16 de libellé).
              if (widget.showAverage && avg > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20 + (avg / maxV * height).clamp(0.0, height),
                  child: IgnorePointer(child: SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _DashPainter(cs.onSurfaceVariant.withOpacity(0.7))))),
                ),
            ]),
          ),
        if (note != null && note.isNotEmpty && !empty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note, style: TextStyle(fontSize: 12, fontWeight: selText != null ? FontWeight.w700 : FontWeight.w400)),
          ),
        if (widget.showAverage && !empty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              SizedBox(width: 16, height: 1, child: CustomPaint(painter: _DashPainter(cs.onSurfaceVariant.withOpacity(0.7)))),
              const SizedBox(width: 6),
              Text('${tr('Moyenne', 'المتوسط')} : ${favg(avg)}', style: const TextStyle(fontSize: 11, color: kMuted)),
            ]),
          ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 4, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

/// Carte d'un indicateur : valeur, libellé et évolution par rapport à la période précédente.
class KpiCard extends StatelessWidget {
  final Object icon;
  final String value, label;
  final double? delta; // null = pas de comparaison
  final String deltaSuffix; // '%' (variation relative) ou ' pt' (écart en points pour un taux)
  final String? hint;
  const KpiCard({super.key, required this.icon, required this.value, required this.label, this.delta, this.deltaSuffix = '%', this.hint});

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
          if (delta != null) _Delta(delta!, deltaSuffix),
        ]),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        Text(hint == null ? label : '$label · $hint', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _Delta extends StatelessWidget {
  final double v;
  final String suffix;
  const _Delta(this.v, this.suffix);
  @override
  Widget build(BuildContext context) {
    final up = v >= 0;
    final flat = v.abs() < 0.5;
    final c = flat ? kMuted : (up ? kOk : kDanger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text('${flat ? '' : (up ? '▲ ' : '▼ ')}${v.abs().round()}$suffix', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
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
